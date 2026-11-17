require "PZAPI/ModOptions";
require "ISUI/ISButton";

TCA_UIScale = TCA_UIScale or {};

local U = TCA_UIScale;

U.OPTIONS_ID = "thecoroner";
U.CHOICES = { 0, 1, 1.25, 1.5, 1.75, 2, 2.5 };
U.CHOICE_KEYS = { "IGUI_TCA_UIScaleAuto", "IGUI_TCA_UIScale100", "IGUI_TCA_UIScale125", "IGUI_TCA_UIScale150", "IGUI_TCA_UIScale175", "IGUI_TCA_UIScale200", "IGUI_TCA_UIScale250" };
U.AUTO_BASE_H = 1080;
U.AUTO_MAX = 2.5;
U.AUTO_STEP = 0.05;
U.FIT_W = 0.96;
U.FIT_H = 0.92;
U.FONT_STEP_1 = 1.3;
U.FONT_STEP_2 = 1.75;
U.FONTS = { UIFont.Small, UIFont.Medium, UIFont.Large };

function U.createOptions()
    if U.options or not PZAPI or not PZAPI.ModOptions then
        return;
    end
    local options = PZAPI.ModOptions:create(U.OPTIONS_ID, "IGUI_TCA_ModOptionsTitle");
    local combo = options:addComboBox("uiScale", "IGUI_TCA_UIScale", "IGUI_TCA_UIScaleTip");
    for i, key in ipairs(U.CHOICE_KEYS) do
        combo:addItem(key, i == 1);
    end
    options:addTickBox("uiScaleFonts", "IGUI_TCA_UIScaleFonts", true, "IGUI_TCA_UIScaleFontsTip");
    options:addTickBox("corpsePreview", "IGUI_TCA_CorpsePreview", true, "IGUI_TCA_CorpsePreviewTip");
    U.options = options;
end

function U.isCorpsePreviewEnabled()
    local option = U.getOption("corpsePreview");
    if not option then
        return true;
    end
    return option:getValue() ~= false;
end

function U.getOption(id)
    if not U.options then
        return nil;
    end
    return U.options:getOption(id);
end

function U.getChoice()
    local option = U.getOption("uiScale");
    if not option then
        return 0;
    end
    return U.CHOICES[tonumber(option:getValue()) or 1] or 0;
end

function U.scaleFonts()
    local option = U.getOption("uiScaleFonts");
    if not option then
        return true;
    end
    return option:getValue() ~= false;
end

function U.getAuto()
    local h = getCore():getScreenHeight();
    local k = h / U.AUTO_BASE_H;
    k = math.floor(k / U.AUTO_STEP + 0.5) * U.AUTO_STEP;
    return math.max(1, math.min(U.AUTO_MAX, k));
end

function U.getWanted()
    local choice = U.getChoice();
    if choice <= 0 then
        return U.getAuto();
    end
    return choice;
end

function U.get(baseW, baseH)
    local k = U.getWanted();
    local core = getCore();
    local fit = math.min(core:getScreenWidth() * U.FIT_W / baseW, core:getScreenHeight() * U.FIT_H / baseH);
    if k > fit then
        k = fit;
    end
    if k < 1 then
        k = 1;
    end
    return k;
end

function U.font(base, k)
    if not U.scaleFonts() then
        return base;
    end
    local shift = 0;
    if k >= U.FONT_STEP_2 then
        shift = 2;
    elseif k >= U.FONT_STEP_1 then
        shift = 1;
    end
    if shift == 0 then
        return base;
    end
    local index = nil;
    for i, f in ipairs(U.FONTS) do
        if f == base then
            index = i;
        end
    end
    if not index then
        return base;
    end
    return U.FONTS[math.min(index + shift, #U.FONTS)];
end

function U.apply(ui, k)
    ui.k = k;
    ui.fontSmall = U.font(UIFont.Small, k);
    ui.fontMedium = U.font(UIFont.Medium, k);
    local tm = getTextManager();
    ui.smallH = tm:getFontHeight(ui.fontSmall);
    ui.mediumH = tm:getFontHeight(ui.fontMedium);
end

function U.px(ui, v)
    return v * (ui.k or 1);
end

function U.button(ui, x, y, w, h, title, target, onClick)
    local height = math.max(h, getTextManager():getFontHeight(ui.fontSmall) + 6);
    local btn = ISButton:new(x, y, w, height, title, target, onClick);
    btn:initialise();
    btn:instantiate();
    btn:setFont(ui.fontSmall);
    return btn;
end

U.createOptions();
