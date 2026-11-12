require "TCA_Client";

TCA_WoundsCompat = {};
TCA_WoundsCompat.registered = false;
TCA_WoundsCompat.MOD_ID = "WoundsOverhaul";
TCA_WoundsCompat.MENU_KEY = "IGUI_Wounds_PracticeMenu";
TCA_WoundsCompat.MENU_FALLBACK = "Practise on the body";
TCA_WoundsCompat.FIELDS = { "notAvailable", "toolTip", "iconTexture", "color", "checkMark" };

function TCA_WoundsCompat.isModActivated()
    local mods = getActivatedMods();
    if not mods then
        return false;
    end
    for i = 0, mods:size() - 1 do
        local id = tostring(mods:get(i));
        id = string.gsub(id, "^\\+", "");
        if id == TCA_WoundsCompat.MOD_ID then
            return true;
        end
    end
    return false;
end

function TCA_WoundsCompat.isActive()
    if not TCA_WoundsCompat.isModActivated() then
        return false;
    end
    return Wounds ~= nil and Wounds.practice ~= nil;
end

function TCA_WoundsCompat.getMenuName()
    if Wounds and Wounds.text then
        return Wounds.text(TCA_WoundsCompat.MENU_KEY, TCA_WoundsCompat.MENU_FALLBACK);
    end
    local text = getText(TCA_WoundsCompat.MENU_KEY);
    if text == nil or text == TCA_WoundsCompat.MENU_KEY then
        return TCA_WoundsCompat.MENU_FALLBACK;
    end
    return text;
end

function TCA_WoundsCompat.copyOption(option)
    local copy = {};
    copy.name = option.name;
    copy.target = option.target;
    copy.onSelect = option.onSelect;
    copy.params = { option.param1, option.param2, option.param3, option.param4, option.param5, option.param6, option.param7, option.param8, option.param9, option.param10 };
    copy.subOption = option.subOption;
    copy.extra = {};
    for _, field in ipairs(TCA_WoundsCompat.FIELDS) do
        copy.extra[field] = option[field];
    end
    return copy;
end

function TCA_WoundsCompat.moveOption(context, name, body)
    local option = context:getOptionFromName(name);
    if not option then
        return;
    end
    local copy = TCA_WoundsCompat.copyOption(option);
    context:removeOptionByName(name);
    local sub = TCA_Client.getSubMenu(context);
    local p = copy.params;
    local moved = sub:addOption(copy.name, copy.target, copy.onSelect, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10]);
    for _, field in ipairs(TCA_WoundsCompat.FIELDS) do
        moved[field] = copy.extra[field];
    end
    if copy.subOption then
        moved.subOption = copy.subOption;
        local practiceMenu = context:getSubMenu(copy.subOption);
        if practiceMenu then
            practiceMenu.parent = sub;
        end
    end
    if body then
        ISWorldObjectContextMenu.initWorldItemHighlightOption(moved, body);
    end
    sub:setWidth(sub:calcWidth());
    context:setWidth(context:calcWidth());
end

function TCA_WoundsCompat.onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then
        return;
    end
    local fetch = ISWorldObjectContextMenu.fetchVars;
    local body = nil;
    if fetch and fetch.body and instanceof(fetch.body, "IsoDeadBody") then
        body = fetch.body;
    end
    TCA_WoundsCompat.moveOption(context, TCA_WoundsCompat.getMenuName(), body);
end

function TCA_WoundsCompat.onGameStart()
    if TCA_WoundsCompat.registered or not TCA_WoundsCompat.isActive() then
        return;
    end
    TCA_WoundsCompat.registered = true;
    Events.OnFillWorldObjectContextMenu.Add(TCA_WoundsCompat.onFillWorldObjectContextMenu);
end

Events.OnGameStart.Add(TCA_WoundsCompat.onGameStart);
