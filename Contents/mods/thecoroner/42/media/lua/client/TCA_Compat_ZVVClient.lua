require "TCA_Compat_ZVV";
require "TimedActions/TCA_ZVVAutopsyAction";
require "TimedActions/TCA_ZVVPartAction";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.ZVVClient = TCA.Compat.ZVVClient or {};

local C = TCA.Compat.ZVVClient;
local Z = TCA.Compat.ZVV;

C.BLOCKED_KEYS = { "ContextMenu_LabCorpseAutopsy", "ContextMenu_LabPutCorpseOnTable" };

function C.removeAll(context, name)
    while context:getOptionFromName(name) do
        context:removeOptionByName(name);
    end
end

function C.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test or not context or not Z.isMenuBlocked() then
        return;
    end
    for _, key in ipairs(C.BLOCKED_KEYS) do
        C.removeAll(context, getText(key));
    end
end

function C.register()
    if C.registered or not Z.isActive() then
        return;
    end
    Events.OnFillWorldObjectContextMenu.Add(C.onFillWorldObjectContextMenu);
    C.registered = true;
end

function C.setIcon(option, fullType)
    local script = ScriptManager.instance:FindItem(fullType);
    if script and script:getNormalTexture() then
        option.iconTexture = script:getNormalTexture();
    end
end

function C.appendLine(option, text)
    if not option.toolTip then
        option.toolTip = ISWorldObjectContextMenu.addToolTip();
    end
    if option.toolTip.description ~= "" then
        option.toolTip.description = option.toolTip.description .. " <LINE> ";
    end
    option.toolTip.description = option.toolTip.description .. "<RGB:1,0.4,0.4> " .. text .. " <RGB:1,1,1> ";
    option.notAvailable = true;
end

function C.wear(playerObj, item)
    if item and not playerObj:isEquippedClothing(item) then
        ISInventoryPaneContextMenu.wearItem(item, playerObj:getPlayerNum());
    end
end

function C.equip(playerObj, item, primary)
    if not item then
        return;
    end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item);
    ISInventoryPaneContextMenu.equipWeapon(item, primary, false, playerObj:getPlayerNum());
end

function C.onAutopsy(playerObj, body)
    if not body or not body:getSquare() then
        return;
    end
    local inv = playerObj:getInventory();
    local scalpel = Z.findScalpel(inv);
    local tweezers = Z.findTweezers(inv);
    if not scalpel or not tweezers then
        return;
    end
    if not luautils.walkAdj(playerObj, body:getSquare(), false) then
        return;
    end
    C.wear(playerObj, Z.findFirst(inv, Z.MASKS, Z.notBroken));
    C.wear(playerObj, Z.findFirst(inv, Z.GLOVES, Z.notBroken));
    C.equip(playerObj, scalpel, true);
    C.equip(playerObj, tweezers, false);
    ISTimedActionQueue.add(TCA_ZVVAutopsyAction:new(playerObj, body:getX(), body:getY(), body:getZ(), Z.isOnTable(body)));
end

function C.onCollectPart(playerObj, body, partId)
    if not body or not body:getSquare() then
        return;
    end
    local inv = playerObj:getInventory();
    local scalpel = Z.findScalpel(inv);
    local saw = Z.findSaw(inv);
    if not scalpel or not saw then
        return;
    end
    if not luautils.walkAdj(playerObj, body:getSquare(), false) then
        return;
    end
    C.equip(playerObj, saw, true);
    C.equip(playerObj, scalpel, false);
    ISTimedActionQueue.add(TCA_ZVVPartAction:new(playerObj, body:getX(), body:getY(), body:getZ(), partId));
end

function C.addAutopsyOption(menu, playerObj, body)
    local option = TCA_Client.addBodyOption(menu, body, getText("ContextMenu_TCA_ZVVBlood"), playerObj, C.onAutopsy, body);
    C.setIcon(option, "Base.Scalpel");
    local notFresh = not Z.isFresh(body);
    local notZombie = not body:isZombie();
    local done = Z.isAutopsied(body);
    if LabRecipes_CreateCorpseAutopsyTooltip then
        LabRecipes_CreateCorpseAutopsyTooltip(option, playerObj:getInventory(), notFresh, notZombie, done);
    elseif notFresh or notZombie or done then
        option.notAvailable = true;
    end
    if not Z.isOnTable(body) and not Z.isGroundAllowed() then
        C.appendLine(option, getText("ContextMenu_LabCannotAutopsyHere"));
    end
end

function C.addPartsMenu(menu, playerObj, body)
    local parent = menu:addOption(getText("ContextMenu_TCA_ZVVParts"));
    C.setIcon(parent, "Base.Saw");
    local sub = ISContextMenu:getNew(menu);
    menu:addSubMenu(parent, sub);
    local inv = playerObj:getInventory();
    local hasScalpel = Z.findScalpel(inv) ~= nil;
    local hasSaw = Z.findSaw(inv) ~= nil;
    local onTable = Z.isOnTable(body);
    local done = Z.isAutopsied(body);
    for _, part in ipairs(Z.PARTS) do
        local option = TCA_Client.addBodyOption(sub, body, getText(part.text), playerObj, C.onCollectPart, body, part.id);
        C.setIcon(option, part.icon);
        option.toolTip = ISWorldObjectContextMenu.addToolTip();
        if Z.isPartTaken(body, part.id) then
            C.appendLine(option, getText("Tooltip_TCA_ZVVPartTaken"));
        end
        if not onTable then
            C.appendLine(option, getText("Tooltip_TCA_ZVVNeedTable"));
        end
        if not done then
            C.appendLine(option, getText("Tooltip_TCA_ZVVNeedAutopsy"));
        end
        if not hasScalpel then
            C.appendLine(option, getText("Tooltip_TCA_NeedScalpel"));
        end
        if not hasSaw then
            C.appendLine(option, getText("Tooltip_TCA_ZVVNeedSaw"));
        end
        if not option.notAvailable then
            option.toolTip = nil;
        end
    end
end

function C.addMenu(context, playerObj, body)
    if not Z.isActive() or not body then
        return;
    end
    local parent = context:addOption(getText("ContextMenu_TCA_ZVV"));
    local menu = ISContextMenu:getNew(context);
    context:addSubMenu(parent, menu);
    C.addAutopsyOption(menu, playerObj, body);
    C.addPartsMenu(menu, playerObj, body);
end

Events.OnGameStart.Add(C.register);
