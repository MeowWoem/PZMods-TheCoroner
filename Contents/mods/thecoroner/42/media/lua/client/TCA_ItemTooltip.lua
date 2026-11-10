require "ISUI/ISToolTipInv"

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

function T.isBodyItem(item)
    if not item then
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

function T.render(self)
    T.originalRender(self);
    if self.item and self.item:getFullType() == "TCA.SpentBullet" then
        T.drawExtra(self, T.getBulletLines(self.item));
        return;
    end
    if not T.isBodyItem(self.item) then
        return;
    end
    local character = nil;
    if self.tooltip then
        character = self.tooltip:getCharacter();
    end
    if not character then
        character = getPlayer();
    end
    local lines = T.getLines(self.item, character);
    if #lines > 0 then
        T.drawExtra(self, lines);
    end
end

if not T.originalRender then
    T.originalRender = ISToolTipInv.render;
    ISToolTipInv.render = T.render;
end
