require "ISUI/ISToolTipInv";

TCA = TCA or {};
TCA.ItemTooltip = TCA.ItemTooltip or {};

local T = TCA.ItemTooltip;

T.PAD_X = 5;
T.PAD_Y = 4;
T.LINE_GAP = 2;
T.FONT = UIFont.Small;
T.TEXT = { r = 0.8, g = 0.8, b = 0.8 };
T.GOOD = { r = 0.55, g = 0.9, b = 0.6 };
T.BAD = { r = 1, g = 0.45, b = 0.4 };
T.INFECTED = { r = 0.75, g = 0.6, b = 0.85 };
T.BULLET_ITEM = "TCA.SpentBullet";
T.TOOLTIPLIB_ID = "TooltipLib";

function T.isInventoryItem(item)
    return item ~= nil and instanceof(item, "InventoryItem");
end

function T.isBodyItem(item)
    if not T.isInventoryItem(item) then
        return false;
    end
    local fullType = item:getFullType();
    if fullType == TCA.Autopsy.CHEST_PLATE_ITEM then
        return true;
    end
    return string.sub(fullType, 1, #TCA.Autopsy.ORGAN_ITEM_PREFIX) == TCA.Autopsy.ORGAN_ITEM_PREFIX;
end

function T.getLookLevel()
    if TCA_AutopsyUI and TCA_AutopsyUI.ORGAN_LOOK_LEVEL then
        return TCA_AutopsyUI.ORGAN_LOOK_LEVEL;
    end
    return 3;
end

function T.getDetailLevel()
    if TCA_AutopsyUI and TCA_AutopsyUI.ORGAN_DETAIL_LEVEL then
        return TCA_AutopsyUI.ORGAN_DETAIL_LEVEL;
    end
    return 6;
end

function T.getLines(item, character)
    local lines = {};
    local md = item:getModData();
    local decay = nil;
    if md["TCA_Decay"] ~= nil or TCA_OrganFood.isFood(item) then
        decay = TCA_OrganFood.getDecayLevel(item);
    end
    local level = 0;
    if character then
        level = character:getPerkLevel(Perks.Doctor);
    end
    if decay and level >= T.getLookLevel() then
        decay = math.max(0, math.min(3, math.floor(decay)));
        table.insert(lines, { text = getText("IGUI_TCA_OrganLook", getText("IGUI_TCA_OrganLook_" .. decay)), color = T.TEXT });
    end
    local damage = tonumber(md["TCA_Damage"]);
    if damage then
        damage = math.floor(damage);
        if damage > 0 then
            table.insert(lines, { text = getText("IGUI_TCA_OrganDamagedCount", damage), color = T.BAD });
        else
            table.insert(lines, { text = getText("IGUI_TCA_OrganIntact"), color = T.GOOD });
        end
    end
    if md["TCA_Infected"] == true and level >= T.getDetailLevel() then
        table.insert(lines, { text = getText("IGUI_TCA_OrganInfected"), color = T.INFECTED });
    end
    return lines;
end

function T.drawExtra(tip, lines)
    local tm = getTextManager();
    local lineH = tm:getFontHeight(T.FONT);
    local textW = 0;
    for i = 1, #lines do
        textW = math.max(textW, tm:MeasureStringX(T.FONT, lines[i].text));
    end
    local w = math.max(tip.width, textW + T.PAD_X * 2);
    local h = T.PAD_Y * 2 + #lines * lineH + (#lines - 1) * T.LINE_GAP;
    local y = tip.height - 1;
    if tip:getAbsoluteY() + y + h > getCore():getScreenHeight() then
        y = 1 - h;
    end
    local bg = tip.backgroundColor;
    local border = tip.borderColor;
    tip:drawRect(0, y, w, h, bg.a, bg.r, bg.g, bg.b);
    tip:drawRectBorder(0, y, w, h, border.a, border.r, border.g, border.b);
    local ty = y + T.PAD_Y;
    for i = 1, #lines do
        local c = lines[i].color;
        tip:drawText(lines[i].text, T.PAD_X, ty, c.r, c.g, c.b, 1, T.FONT);
        ty = ty + lineH + T.LINE_GAP;
    end
end

function T.getBulletLines(item)
    local lines = {};
    local ammo = item:getModData()["TCA_Ammo"];
    if ammo then
        table.insert(lines, { text = getText("IGUI_TCA_BulletCaliber", getItemNameFromFullType(ammo)), color = T.TEXT });
    else
        table.insert(lines, { text = getText("IGUI_TCA_BulletUnknown"), color = T.TEXT });
    end
    return lines;
end

function T.getCharacterFor(tooltip)
    local character = nil;
    if tooltip and tooltip.getCharacter then
        character = tooltip:getCharacter();
    end
    if not character then
        character = getPlayer();
    end
    return character;
end

function T.getItemLines(item, tooltip)
    if not T.isInventoryItem(item) then
        return nil;
    end
    if item:getFullType() == T.BULLET_ITEM then
        return T.getBulletLines(item);
    end
    if not T.isBodyItem(item) then
        return nil;
    end
    return T.getLines(item, T.getCharacterFor(tooltip));
end

function T.render(self)
    if type(T.originalRender) == "function" then
        T.originalRender(self);
    end
    local lines = T.getItemLines(self.item, self.tooltip);
    if lines and #lines > 0 then
        T.drawExtra(self, lines);
    end
end

function T.isModActivated(modId)
    local mods = getActivatedMods();
    if not mods then
        return false;
    end
    for i = 0, mods:size() - 1 do
        local id = string.gsub(tostring(mods:get(i)), "^\\+", "");
        if id == modId then
            return true;
        end
    end
    return false;
end

function T.toLibColor(color)
    return { color.r, color.g, color.b, 1 };
end

function T.providerEnabled(item)
    if not T.isInventoryItem(item) then
        return false;
    end
    return item:getFullType() == T.BULLET_ITEM or T.isBodyItem(item);
end

function T.providerCallback(ctx)
    local lines = T.getItemLines(ctx.item, ctx.tooltip);
    if not lines then
        return;
    end
    for i = 1, #lines do
        ctx:addLabel(lines[i].text, T.toLibColor(lines[i].color));
    end
end

function T.registerTooltipLib()
    require "TooltipLib/Core";
    if not TooltipLib or type(TooltipLib.registerProvider) ~= "function" then
        return false;
    end
    local provider = {};
    provider.id = "thecoroner_ItemTooltip";
    provider.target = "item";
    provider.description = "The Coroner: organs, chest plate and bullets";
    provider.enabled = T.providerEnabled;
    provider.callback = T.providerCallback;
    TooltipLib.registerProvider(provider);
    return true;
end

function T.hookRender()
    if T.originalRender ~= nil or T.hooked then
        return;
    end
    local original = ISToolTipInv.render;
    if type(original) ~= "function" then
        return;
    end
    T.originalRender = original;
    T.hooked = true;
    ISToolTipInv.render = T.render;
end

function T.setup()
    if T.isSetUp then
        return;
    end
    T.isSetUp = true;
    if T.isModActivated(T.TOOLTIPLIB_ID) and T.registerTooltipLib() then
        T.usesTooltipLib = true;
        return;
    end
    T.hookRender();
end

T.setup();
