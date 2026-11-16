require "ISUI/ISPanel";
require "ISUI/ISButton";
require "TCA_UIScale";
require "TCA_Cannibalism";
require "TCA_OrganFood";
require "TCA_Organs";
require "TCA_Autopsy";
require "ISUI/ISContextMenu";

TCA_CannibalDebugUI = ISPanel:derive("TCA_CannibalDebugUI");

local D = TCA_CannibalDebugUI;

D.BASE_W = 340;
D.PAD = 10;
D.REFRESH_MS = 1000;
D.TITLE = { r = 1, g = 1, b = 1, a = 1 };
D.SECTION = { r = 1, g = 0.8, b = 0.3, a = 1 };
D.LABEL = { r = 0.75, g = 0.75, b = 0.75, a = 1 };
D.VALUE = { r = 1, g = 1, b = 1, a = 1 };
D.ALERT = { r = 1, g = 0.4, b = 0.4, a = 1 };

D.ROWS = {
    { "section", "Stats" },
    { "pct", "Stress", "stress" },
    { "num", "Unhappy", "unhappy" },
    { "num", "Boredom", "boredom" },
    { "num", "Sickness", "sickness" },
    { "pct", "Morale", "morale" },
    { "bool", "Infected", "infected" },
    { "num", "Infection", "infection" },
    { "section", "Own" },
    { "mod", "Mod", "mod" },
    { "bool", "Effects", "effects" },
    { "num", "Strength", "strength" },
    { "bool", "Trait", "trait" },
    { "pair", "Meals", "meals", "threshold" },
    { "num", "Exposure", "exposure" },
    { "num", "Habit", "habit" },
    { "num", "Sensitivity", "sensitivity" },
    { "hours", "Since", "since" },
    { "hours", "Guilt", "guilt" },
    { "num", "GuiltFloor", "guiltFloor" },
    { "pct", "Craving", "craving" },
    { "section", "Dishes" },
    { "bool", "Hide", "hide" },
    { "pair", "FirstAid", "firstAid", "firstAidReq" },
    { "pair", "Cooking", "cooking", "cookingReq" },
    { "bool", "Suspects", "suspects" },
    { "section", "Mods" },
    { "num", "HarvestZ", "hzPoints" },
    { "bool", "CZATrait", "czaTrait" },
    { "hours", "CZACraving", "czaCraving" },
};

function D.formatNumber(v)
    return string.format("%.2f", tonumber(v) or 0);
end

function D.formatShort(v)
    local n = tonumber(v) or 0;
    if n == math.floor(n) then
        return string.format("%d", n);
    end
    return string.format("%.2f", n);
end

function D.formatValue(row, s)
    local kind = row[1];
    local v = s[row[3]];
    if v == nil then
        return "-";
    end
    if kind == "pct" then
        return string.format("%.0f %%", (tonumber(v) or 0) * 100);
    elseif kind == "bool" then
        if v == true then
            return getText("UI_Yes");
        end
        return getText("UI_No");
    elseif kind == "hours" then
        if (tonumber(v) or -1) < 0 then
            return "-";
        end
        return string.format("%.1f h", tonumber(v));
    elseif kind == "pair" then
        return D.formatShort(v) .. " / " .. D.formatShort(s[row[4]]);
    elseif kind == "mod" then
        if v == "" then
            return getText("IGUI_TCA_DbgCan_None");
        end
        return tostring(v);
    elseif kind == "num" and (tonumber(v) or 0) < 0 then
        return "-";
    end
    return D.formatNumber(v);
end

function D.isAlert(row, s)
    local v = s[row[3]];
    if row[1] == "bool" then
        return v == true and (row[3] == "infected" or row[3] == "suspects" or row[3] == "trait");
    end
    if row[1] == "pct" and row[3] == "craving" then
        return (tonumber(v) or 0) > 0;
    end
    return false;
end

function D:initialise()
    ISPanel.initialise(self);
end

function D:createChildren()
    ISPanel.createChildren(self);
    local k = self.k;
    local w = 70 * k;
    self.closeButton = TCA_UIScale.button(self, self.width - w - D.PAD * k, D.PAD * k, w, 20 * k, getText("UI_Close"), self, D.onCloseClick);
    self:addChild(self.closeButton);
end

function D:onCloseClick()
    self:close();
end

function D:close()
    self:setVisible(false);
    self:removeFromUIManager();
    if D.instance == self then
        D.instance = nil;
    end
end

function D:isRemote()
    return isClient();
end

function D:refresh()
    local target = self.target;
    if not target or not target:isExistInTheWorld() then
        return;
    end
    if self:isRemote() then
        local args = {};
        args.id = target:getOnlineID();
        sendClientCommand(getPlayer(), "TCA", "cannibalDebug", args);
    else
        self.snapshot = TCA.Cannibal.debugSnapshot(target);
    end
end

function D:update()
    ISPanel.update(self);
    local now = getTimestampMs();
    if now - (self.lastRefresh or 0) >= D.REFRESH_MS then
        self.lastRefresh = now;
        self:refresh();
    end
end

function D:render()
    ISPanel.render(self);
    local k = self.k;
    local pad = D.PAD * k;
    local name = self.target and self.target:getDisplayName() or "";
    self:drawText(getText("IGUI_TCA_DbgCan_Title", name), pad, pad, D.TITLE.r, D.TITLE.g, D.TITLE.b, 1, self.fontMedium);
    local y = pad + self.mediumH + 6 * k;
    local s = self.snapshot;
    if not s then
        self:drawText(getText("IGUI_TCA_DbgCan_Waiting"), pad, y, D.LABEL.r, D.LABEL.g, D.LABEL.b, 1, self.fontSmall);
        return;
    end
    local valueX = self.width * 0.62;
    for _, row in ipairs(D.ROWS) do
        if row[1] == "section" then
            y = y + 4 * k;
            self:drawText(getText("IGUI_TCA_DbgCan_" .. row[2]), pad, y, D.SECTION.r, D.SECTION.g, D.SECTION.b, 1, self.fontSmall);
        else
            local color = D.VALUE;
            if D.isAlert(row, s) then
                color = D.ALERT;
            end
            self:drawText(getText("IGUI_TCA_DbgCan_" .. row[2]), pad + 8 * k, y, D.LABEL.r, D.LABEL.g, D.LABEL.b, 1, self.fontSmall);
            self:drawText(D.formatValue(row, s), valueX, y, color.r, color.g, color.b, 1, self.fontSmall);
        end
        y = y + self.smallH;
    end
end

function D.getHeight(ui)
    local sections = 0;
    for _, row in ipairs(D.ROWS) do
        if row[1] == "section" then
            sections = sections + 1;
        end
    end
    return D.PAD * ui.k * 2 + ui.mediumH + 6 * ui.k + #D.ROWS * ui.smallH + sections * 4 * ui.k;
end

function D.receive(args)
    local ui = D.instance;
    if not ui or not ui.target or args.id ~= ui.target:getOnlineID() then
        return;
    end
    ui.snapshot = args;
end

function D.open(target)
    if D.instance then
        D.instance:close();
    end
    local probe = {};
    TCA_UIScale.apply(probe, TCA_UIScale.get(D.BASE_W, 600));
    local w = D.BASE_W * probe.k;
    local h = D.getHeight(probe);
    local ui = D:new(60 * probe.k, 120 * probe.k, w, h, target, probe.k);
    ui:initialise();
    ui:instantiate();
    ui:addToUIManager();
    D.instance = ui;
    ui:refresh();
    return ui;
end

function D:new(x, y, width, height, target, k)
    local o = ISPanel.new(self, x, y, width, height);
    TCA_UIScale.apply(o, k);
    o.target = target;
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 };
    o.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 };
    o.moveWithMouse = true;
    o.lastRefresh = 0;
    return o;
end

function D.onOpen(target)
    D.open(target);
end

D.DECAY_LEVELS = 3;

function D.giveOrgan(playerObj, fullType, decay, infected)
    if isClient() then
        local args = {};
        args.fullType = fullType;
        args.decay = decay;
        args.infected = infected;
        sendClientCommand(playerObj, "TCA", "debugGiveOrgan", args);
    else
        TCA_OrganFood.debugGive(playerObj, fullType, decay, infected);
    end
end

function D.onGiveOrgan(playerObj, fullType, decay, infected)
    if fullType == "" then
        for _, organ in ipairs(TCA.Organs.LIST) do
            D.giveOrgan(playerObj, TCA.Autopsy.ORGAN_ITEM_PREFIX .. organ.id, decay, infected);
        end
        return;
    end
    D.giveOrgan(playerObj, fullType, decay, infected);
end

function D.getStateLabel(decay, infected)
    local state = getText("IGUI_TCA_DebugOrganState_" .. decay);
    if infected then
        return getText("IGUI_TCA_DebugOrganInfected", state);
    end
    return getText("IGUI_TCA_DebugOrganHealthy", state);
end

function D.addStateMenu(context, parent, name, playerObj, fullType)
    local option = parent:addOption(name);
    local states = ISContextMenu:getNew(context);
    context:addSubMenu(option, states);
    for decay = 0, D.DECAY_LEVELS do
        states:addOption(D.getStateLabel(decay, false), playerObj, D.onGiveOrgan, fullType, decay, false);
    end
    for decay = 0, D.DECAY_LEVELS do
        states:addOption(D.getStateLabel(decay, true), playerObj, D.onGiveOrgan, fullType, decay, true);
    end
end

function D.addGiveMenu(context, sub, playerObj)
    local option = sub:addOption(getText("ContextMenu_TCA_DebugGiveOrgan"));
    local organs = ISContextMenu:getNew(context);
    context:addSubMenu(option, organs);
    D.addStateMenu(context, organs, getText("ContextMenu_TCA_DebugGiveAllOrgans"), playerObj, "");
    for _, organ in ipairs(TCA.Organs.LIST) do
        local fullType = TCA.Autopsy.ORGAN_ITEM_PREFIX .. organ.id;
        D.addStateMenu(context, organs, getItemNameFromFullType(fullType), playerObj, fullType);
    end
end

function D.onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test or not TCA_Client or not TCA_Client.isDebug() then
        return;
    end
    local playerObj = getSpecificPlayer(player);
    if not playerObj then
        return;
    end
    local sub = TCA_Client.getSubMenu(context);
    sub:addOption(getText("ContextMenu_TCA_DebugCannibal"), playerObj, D.onOpen);
    D.addGiveMenu(context, sub, playerObj);
    local fetch = ISWorldObjectContextMenu.fetchVars;
    local other = fetch and fetch.clickedPlayer;
    if other and other ~= playerObj and not other:isAnimal() then
        sub:addOption(getText("ContextMenu_TCA_DebugCannibalOf", other:getDisplayName()), other, D.onOpen);
    end
end

Events.OnFillWorldObjectContextMenu.Add(D.onFillWorldObjectContextMenu);
