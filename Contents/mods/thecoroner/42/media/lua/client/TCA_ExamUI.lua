require "ISUI/ISComboBox";
require "TCA_Wounds";
require "TCA_UIDrag";
require "ISUI/ISPanel";
require "ISUI/ISButton";
require "TCA_Shared";
require "TCA_Exam";
require "TCA_OrganFood";
require "TCA_Cold";
require "TCA_BodyRenderer";
require "TCA_UIScale";

TCA_ExamUI = ISPanel:derive("TCA_ExamUI");

TCA_ExamUI.WIDTH = 800;
TCA_ExamUI.HEIGHT = 660;
TCA_ExamUI.VIEW = { x1 = -130, y1 = -20, x2 = 130, y2 = 490 };

TCA_ExamUI.ORDER = { "temp", "eyes", "jaw", "arm", "livor", "decomp", "insects" };
TCA_ExamUI.ZONES = {
    temp = { x = -30, y = 122, radius = 12 },
    eyes = { x = 12.5, y = 31.5, radius = 6 },
    insects = { x = 0, y = 44, radius = 6 },
    w_Head = { x = 0, y = 25, radius = 9 },
    w_Neck = { x = 0, y = 80, radius = 9 },
    w_Torso_Upper = { x = 0, y = 135, radius = 9 },
    w_UpperArm_R = { x = -50, y = 145, radius = 9 },
    w_UpperArm_L = { x = 50, y = 145, radius = 9 },
    w_Torso_Lower = { x = 0, y = 190, radius = 9 },
    w_ForeArm_R = { x = -58, y = 200, radius = 9 },
    w_ForeArm_L = { x = 58, y = 200, radius = 9 },
    w_Groin = { x = 0, y = 235, radius = 9 },
    w_Hand_R = { x = -75, y = 250, radius = 9 },
    w_Hand_L = { x = 75, y = 250, radius = 9 },
    w_UpperLeg_R = { x = -18, y = 280, radius = 9 },
    w_UpperLeg_L = { x = 18, y = 280, radius = 9 },
    w_LowerLeg_R = { x = -18, y = 368, radius = 9 },
    w_LowerLeg_L = { x = 18, y = 368, radius = 9 },
    w_Foot_R = { x = -18, y = 438, radius = 9 },
    w_Foot_L = { x = 18, y = 438, radius = 9 },
    jaw = { x = 0, y = 64, radius = 12 },
    arm = { x = 75, y = 250, radius = 12 },
    livor = { x = 25, y = 185, radius = 12 },
    decomp = { x = 0, y = 205, radius = 16 },
};

TCA_ExamUI.HOLD_MS = { temp = 3000, livor = 1500, decomp = 800, eyes = 1000, insects = 1200 };
TCA_ExamUI.WOUND_HOLD_MS = 800;
TCA_ExamUI.DIGITAL_TEMP_HOLD_MS = 1000;
TCA_ExamUI.CAUSE_H = 58;
TCA_ExamUI.HOLD_TOLERANCE = 10;
TCA_ExamUI.PULL = { jaw = 18, arm = 70 };
TCA_ExamUI.PULL_DONE = 0.9;
TCA_ExamUI.RIGOR_RESIST = 0.9;
TCA_ExamUI.BLANCH_SHOW_MS = 5000;
TCA_ExamUI.TOOL_CHECK_MS = 500;
TCA_ExamUI.WARN_MS = 1500;
TCA_ExamUI.LIVOR_HALF_W = 6;
TCA_ExamUI.LIVOR_UP = 45;
TCA_ExamUI.LIVOR_DOWN = 40;
TCA_ExamUI.LIVOR_STEP = 6;
TCA_ExamUI.LIVOR_RADIUS = 4;
TCA_ExamUI.SCROLL_STEP = 3;
TCA_ExamUI.SCROLL_W = 6;
TCA_ExamUI.EDIT_RADIUS = 10;
TCA_ExamUI.BAR_GRAB = 14;
TCA_ExamUI.HANDLE_GAP = 0.01;
TCA_ExamUI.GUIDE_LINES = 9;
TCA_ExamUI.TOOLTIP_W = 260;
TCA_ExamUI.TOOLTIP_PAD = 6;

local WHITE = { r = 1, g = 1, b = 1 };
local GREEN = { r = 0.2, g = 0.9, b = 0.3 };
local GREY = { r = 0.55, g = 0.55, b = 0.58 };
local GUIDE_TITLE = { r = 0.95, g = 0.85, b = 0.6 };
local GUIDE_TEXT = { r = 0.85, g = 0.85, b = 0.85 };
local RED = { r = 1, g = 0.3, b = 0.25 };
local ORANGE = { r = 1, g = 0.6, b = 0.25 };
local LIVOR = { r = 0.42, g = 0.16, b = 0.36 };
local BLANCH = { r = 0.86, g = 0.76, b = 0.7 };
local GLASS = { r = 0.85, g = 0.9, b = 0.94 };
local PANEL_BG = { r = 0.04, g = 0.04, b = 0.05 };
local BORDER = { r = 0.3, g = 0.3, b = 0.32 };

local function dist(x1, y1, x2, y2)
    local dx = x2 - x1;
    local dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
end

local function clamp(v, lo, hi)
    if v < lo then
        return lo;
    end
    if v > hi then
        return hi;
    end
    return v;
end

function TCA_ExamUI:setView(view)
    local fw = view.x2 - view.x1;
    local fh = view.y2 - view.y1;
    self.scale = math.min(self.viewW / fw, self.viewH / fh);
    self.offX = self.viewX + (self.viewW - fw * self.scale) / 2 - view.x1 * self.scale;
    self.offY = self.viewY + (self.viewH - fh * self.scale) / 2 - view.y1 * self.scale;
end

function TCA_ExamUI:toScreen(x, y)
    return self.offX + x * self.scale, self.offY + y * self.scale;
end

function TCA_ExamUI:toBody(x, y)
    return (x - self.offX) / self.scale, (y - self.offY) / self.scale;
end

function TCA_ExamUI:fillCircleScreen(cx, cy, radius, c, a)
    local steps = 20;
    local prevX = cx + radius;
    local prevY = cy;
    for i = 1, steps do
        local ang = (i / steps) * math.pi * 2;
        local x = cx + math.cos(ang) * radius;
        local y = cy + math.sin(ang) * radius;
        self:drawPolygon(nil, cx, cy, prevX, prevY, x, y, x, y, c.r, c.g, c.b, a or 1);
        prevX = x;
        prevY = y;
    end
end

function TCA_ExamUI:thickLineScreen(x1, y1, x2, y2, width, c, a)
    local len = dist(x1, y1, x2, y2);
    if len < 0.01 then
        return;
    end
    local nx = -(y2 - y1) / len * width / 2;
    local ny = (x2 - x1) / len * width / 2;
    self:drawPolygon(nil, x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, c.r, c.g, c.b, a or 1);
end

function TCA_ExamUI:drawArc(cx, cy, radius, width, fraction, c, a)
    local steps = math.max(2, math.floor(24 * fraction));
    local prevX = cx;
    local prevY = cy - radius;
    for i = 1, steps do
        local ang = -math.pi / 2 + (i / steps) * math.pi * 2 * fraction;
        local x = cx + math.cos(ang) * radius;
        local y = cy + math.sin(ang) * radius;
        self:thickLineScreen(prevX, prevY, x, y, width, c, a);
        prevX = x;
        prevY = y;
    end
end

function TCA_ExamUI.wrapText(font, text, maxW)
    local tm = getTextManager();
    local lines = {};
    local current = "";
    for word in string.gmatch(text, "%S+") do
        local candidate = word;
        if current ~= "" then
            candidate = current .. " " .. word;
        end
        if current ~= "" and tm:MeasureStringX(font, candidate) > maxW then
            table.insert(lines, current);
            current = word;
        else
            current = candidate;
        end
    end
    if current ~= "" then
        table.insert(lines, current);
    end
    return lines;
end

function TCA_ExamUI:initialise()
    ISPanel.initialise(self);
    local E = TCA.Exam;
    TCA_UIScale.apply(self, self.uiScale or 1);
    local k = self.k;
    self.titleH = self.mediumH;
    self.buttonH = math.max(25 * k, self.smallH + 6);
    self.smallButtonH = math.max(20 * k, self.smallH + 4);
    self.comboH = math.max(22 * k, self.smallH + 6);
    self.causeH = math.max(TCA_ExamUI.CAUSE_H * k, self.comboH + self.smallH * 2 + 12 * k);
    self.titleY = 10 * k;
    self.instructionsY = self.titleY + self.titleH + 4 * k;
    self.viewX = 20 * k;
    self.viewY = self.instructionsY + self.smallH + 12 * k;
    self.viewW = 300 * k;
    self.barH = 8 * k;
    local bottom = 14 * k + self.smallH + 16 * k + self.barH + 6 * k + self.smallH + 12 * k + self.buttonH + 12 * k;
    self.viewH = self.height - self.viewY - math.max(170 * k, bottom);
    self.notesX = self.viewX + self.viewW + 20 * k;
    self.notesY = self.viewY;
    self.notesW = self.width - self.notesX - 20 * k;
    self.notesH = self.viewH;
    self.rangeY = self.viewY + self.viewH + 14 * k;
    self.barY = self.rangeY + self.smallH + 16 * k;
    self.barX1 = 50 * k;
    self.barX2 = self.width - 50 * k;
    self:setView(TCA_ExamUI.VIEW);

    self.level = E.getLevel(self.character);
    self.values = E.readAll(self.body, self.level);
    self.done = {};
    self.texts = {};
    self.observedAt = {};
    self.woundLevels = {};
    self.observerKey = E.getObserverKey(self.character);
    self:computeAnatomy();
    self:loadObservations();
    self:applyAnatomyTexts();
    self.press = nil;
    self.blanch = nil;
    self.warnTime = 0;
    self.mode = "notes";
    self.finished = false;
    self.conclude = false;
    self.dragHandle = nil;
    self.scroll = 0;
    self.contentH = 0;
    self.scrollDrag = nil;
    self.editMode = false;
    self.editZone = nil;
    self.result = E.getResult(self.body, self.observerKey);
    self.minPos = 0.3;
    self.maxPos = 0.45;
    if self.result then
        self.minPos = E.hoursToPos(self.result.minHours);
        self.maxPos = E.hoursToPos(self.result.maxHours);
    end
    self:updateThermometer();
    self.toolCheckTime = getTimestampMs();
end

function TCA_ExamUI:createChildren()
    ISPanel.createChildren(self);
    local k = self.k;
    local btnW = 140 * k;
    local y = self.height - self.buttonH - 12 * k;
    self.closeButton = TCA_UIScale.button(self, self.width / 2 - btnW - 10 * k, y, btnW, self.buttonH, getText("IGUI_TCA_ExamClose"), self, TCA_ExamUI.onCloseClick);
    self:addChild(self.closeButton);

    self.concludeButton = TCA_UIScale.button(self, self.width / 2 + 10 * k, y, btnW, self.buttonH, getText("IGUI_TCA_ExamConclude"), self, TCA_ExamUI.onConcludeClick);
    self:addChild(self.concludeButton);
    self.concludeButton:setEnable(self.result == nil);
    if self.result then
        self.concludeButton:setTooltip(getText("IGUI_TCA_ExamAlreadyConcluded"));
    end

    local guideW = 120 * k;
    self.guideButton = TCA_UIScale.button(self, self.notesX + self.notesW - guideW - 6 * k, self.notesY + 6 * k, guideW, self.smallButtonH, getText("IGUI_TCA_ExamGuide"), self, TCA_ExamUI.onGuideClick);
    self:addChild(self.guideButton);

    local causeY = self.notesY + self.notesH - self.causeH + 8 * k;
    local causeBtnW = 110 * k;
    self.causeCombo = ISComboBox:new(self.notesX + 10 * k, causeY, self.notesW - causeBtnW - 30 * k, self.comboH, self, nil);
    self.causeCombo.font = self.fontSmall;
    self.causeCombo:initialise();
    self.causeCombo:instantiate();
    for _, cause in ipairs(TCA.Wounds.getCauseChoices()) do
        self.causeCombo:addOptionWithData(getText("IGUI_TCA_Cause_" .. cause), cause);
    end
    self:addChild(self.causeCombo);
    self.causeButton = TCA_UIScale.button(self, self.notesX + self.notesW - causeBtnW - 10 * k, causeY, causeBtnW, self.comboH, getText("IGUI_TCA_ExamConclude"), self, TCA_ExamUI.onCauseClick);
    self:addChild(self.causeButton);
    self.causeGiven = nil;

    self.woundsButton = TCA_UIScale.button(self, self.notesX + self.notesW - guideW * 2 - 12 * k, self.notesY + 6 * k, guideW, self.smallButtonH, getText("IGUI_TCA_ExamWounds"), self, TCA_ExamUI.onWoundsClick);
    self:addChild(self.woundsButton);
    self.woundsButtonX = self.woundsButton:getX();

    if TCA_Client.isDebug() then
        self.editButton = TCA_UIScale.button(self, 10 * k, y + 2 * k, 130 * k, self.smallButtonH, getText("IGUI_TCA_ExamDebugEdit"), self, TCA_ExamUI.onEditClick);
        self:addChild(self.editButton);
    end

    self:createBodyModel();
    self:updateCauseControls();
end

function TCA_ExamUI:createBodyModel()
    self.model = nil;
    if not TCA_BodyRenderer.USE_MODEL or not self.body then
        return;
    end
    local model = TCA_BodyRenderer.createModel(self, self.viewX, self.viewY, self.viewW, self.viewH);
    model.forwardTo = self;
    TCA_BodyRenderer.applyAppearance(model, TCA_BodyRenderer.buildDescFromBody(self.body), true);
    TCA_BodyRenderer.applyCamera(model, self);
    self.model = model;
end

function TCA_ExamUI:onCloseClick()
    self.press = nil;
    self.finished = true;
end

function TCA_ExamUI:isRangeTooWide()
    local E = TCA.Exam;
    return E.isRangeTooWide(E.posToHours(self.minPos), E.posToHours(self.maxPos));
end

function TCA_ExamUI:updateConcludeButton()
    if self.result or not self.concludeButton then
        return;
    end
    local tooWide = self:isRangeTooWide();
    if tooWide == self.lastTooWide then
        return;
    end
    self.lastTooWide = tooWide;
    self.concludeButton:setEnable(not tooWide);
    if tooWide then
        self.concludeButton:setTooltip(getText("IGUI_TCA_ExamTooWideTip", TCA.Exam.formatMaxRatio()));
    else
        self:hideButtonTooltip(self.concludeButton);
        self.concludeButton:setTooltip(nil);
    end
end

function TCA_ExamUI:onConcludeClick()
    if self.result or self:isRangeTooWide() then
        return;
    end
    self.conclude = true;
    self.finished = true;
end

function TCA_ExamUI:onEditClick()
    self.editMode = not self.editMode;
    self.editZone = nil;
    self.press = nil;
    self:updateCauseControls();
end

function TCA_ExamUI:editMouseDown(x, y)
    if not self.editMode or not self:isInView(x, y) then
        return false;
    end
    for _, id in ipairs(self:getZoneIds()) do
        local zx, zy = self:getZoneScreen(id);
        if dist(x, y, zx, zy) <= TCA_ExamUI.EDIT_RADIUS * self.k then
            self.editZone = id;
            return true;
        end
    end
    return true;
end

function TCA_ExamUI:updateEdit()
    if not self.editZone then
        return;
    end
    local bx, by = self:toBody(self:getMouseX(), self:getMouseY());
    local zone = TCA_ExamUI.ZONES[self.editZone];
    zone.x = math.floor(bx * 2 + 0.5) / 2;
    zone.y = math.floor(by * 2 + 0.5) / 2;
end

function TCA_ExamUI:releaseEdit()
    if not self.editZone then
        return;
    end
    local zone = TCA_ExamUI.ZONES[self.editZone];
    print("TCA: exam zone " .. self.editZone .. " = { x = " .. tostring(zone.x) .. ", y = " .. tostring(zone.y) .. " }");
    self.editZone = nil;
end

function TCA_ExamUI:drawEditLabels()
    if not self.editMode then
        return;
    end
    for _, id in ipairs(self:getZoneIds()) do
        local zone = TCA_ExamUI.ZONES[id];
        local zx, zy = self:getZoneScreen(id);
        self:drawText(id .. " " .. tostring(zone.x) .. ", " .. tostring(zone.y), zx + 8 * self.k, zy - 6 * self.k, 1, 0.85, 0.3, 1, self.fontSmall);
    end
end

function TCA_ExamUI:getNotesContentTop()
    return self.notesY + self.titleH + 16 * self.k;
end

function TCA_ExamUI:getNotesContentH()
    local h = self.notesY + self.notesH - self:getNotesContentTop() - 6 * self.k;
    if self.mode == "wounds" then
        h = h - self.causeH;
    end
    return h;
end

function TCA_ExamUI:getMaxScroll()
    return math.max(0, self.contentH - self:getNotesContentH());
end

function TCA_ExamUI:setScroll(value)
    self.scroll = clamp(value, 0, self:getMaxScroll());
end

function TCA_ExamUI:isOverNotes(x, y)
    return x >= self.notesX and y >= self.notesY and x < self.notesX + self.notesW and y < self.notesY + self.notesH;
end

function TCA_ExamUI:getScrollThumb()
    local top = self:getNotesContentTop();
    local trackH = self:getNotesContentH();
    if self.contentH <= trackH then
        return nil;
    end
    local thumbH = math.max(20 * self.k, trackH * trackH / self.contentH);
    local thumbY = top + (trackH - thumbH) * self.scroll / self:getMaxScroll();
    local thumb = {};
    thumb.w = TCA_ExamUI.SCROLL_W * self.k;
    thumb.x = self.notesX + self.notesW - thumb.w - 3 * self.k;
    thumb.y = thumbY;
    thumb.h = thumbH;
    thumb.top = top;
    thumb.trackH = trackH;
    return thumb;
end

function TCA_ExamUI:scrollMouseDown(x, y)
    local thumb = self:getScrollThumb();
    if not thumb then
        return false;
    end
    if x < thumb.x - 3 * self.k or x > thumb.x + thumb.w + 3 * self.k or y < thumb.top or y > thumb.top + thumb.trackH then
        return false;
    end
    if y < thumb.y or y > thumb.y + thumb.h then
        self:setScroll(self:getMaxScroll() * (y - thumb.top - thumb.h / 2) / (thumb.trackH - thumb.h));
        thumb = self:getScrollThumb();
    end
    local drag = {};
    drag.startY = y;
    drag.startScroll = self.scroll;
    drag.trackH = thumb.trackH - thumb.h;
    self.scrollDrag = drag;
    return true;
end

function TCA_ExamUI:updateScrollDrag()
    local drag = self.scrollDrag;
    if not drag or drag.trackH <= 0 then
        return;
    end
    local dy = self:getMouseY() - drag.startY;
    self:setScroll(drag.startScroll + dy * self:getMaxScroll() / drag.trackH);
end

function TCA_ExamUI:onMouseWheel(del)
    if not self:isOverNotes(self:getMouseX(), self:getMouseY()) then
        return false;
    end
    self:setScroll(self.scroll + del * self.smallH * TCA_ExamUI.SCROLL_STEP);
    return true;
end

function TCA_ExamUI:canConcludeCause()
    local W = TCA.Wounds;
    return self.mode == "wounds" and self.causeGiven == nil and W.getCauseResult(self.body, self.observerKey) == nil and W.getTrueCause(self.body) ~= nil;
end

function TCA_ExamUI:updateCauseControls()
    local show = self:canConcludeCause();
    self.causeCombo:setVisible(show);
    self.causeButton:setVisible(show);
end

function TCA_ExamUI:onCauseClick()
    if not self:canConcludeCause() then
        return;
    end
    local cause = self.causeCombo:getOptionData(self.causeCombo.selected);
    if not cause then
        return;
    end
    self.causeGiven = cause;
    TCA_Client.concludeCause(self.character, self.body, cause, self.observerKey);
    self:updateCauseControls();
end

function TCA_ExamUI:drawCauseStrip()
    if self.mode ~= "wounds" or self:canConcludeCause() then
        return;
    end
    local W = TCA.Wounds;
    local x = self.notesX + 10 * self.k;
    local y = self.notesY + self.notesH - self.causeH + 8 * self.k;
    local maxW = self.notesW - 20 * self.k;
    local result = W.getCauseResult(self.body, self.observerKey);
    if result then
        local verdict = getText("IGUI_TCA_ExamGivenWrong");
        local c = RED;
        if result.ok then
            verdict = getText("IGUI_TCA_ExamGivenRight");
            c = GREEN;
        end
        self:drawWrapped(getText("IGUI_TCA_CauseGiven", getText("IGUI_TCA_Cause_" .. result.cause), verdict), x, y, maxW, c);
    elseif self.causeGiven then
        self:drawWrapped(getText("IGUI_TCA_CauseGivenPending", getText("IGUI_TCA_Cause_" .. self.causeGiven)), x, y, maxW, WHITE);
    else
        self:drawWrapped(getText("IGUI_TCA_CauseUnknown"), x, y, maxW, GREY);
    end
end

function TCA_ExamUI:setMode(mode)
    self.scroll = 0;
    self.press = nil;
    self.mode = mode;
    self.guideButton:setTitle(getText("IGUI_TCA_ExamGuide"));
    self.woundsButton:setTitle(getText("IGUI_TCA_ExamWounds"));
    self.guideButton:setVisible(mode ~= "wounds");
    if mode == "wounds" then
        self.woundsButton:setX(self.guideButton:getX());
    else
        self.woundsButton:setX(self.woundsButtonX);
    end
    if mode == "guide" then
        self.guideButton:setTitle(getText("IGUI_TCA_ExamNotes"));
    elseif mode == "wounds" then
        self.woundsButton:setTitle(getText("IGUI_TCA_ExamNotes"));
    end
    self:updateCauseControls();
end

function TCA_ExamUI:onGuideClick()
    if self.mode == "guide" then
        self:setMode("notes");
    else
        self:setMode("guide");
    end
end

function TCA_ExamUI:onWoundsClick()
    if self.mode == "wounds" then
        self:setMode("notes");
    else
        self:setMode("wounds");
    end
end

function TCA_ExamUI:computeAnatomy()
    local W = TCA.Wounds;
    self.zonePos = {};
    self.hiddenZones = {};
    self.noMarker = {};
    self.zoneLabels = {};
    self.zoneHints = {};
    self.anatomy = W.getAnatomy(self.body);
    for i = 1, #W.LIMB_CHAINS do
        local chain = W.LIMB_CHAINS[i];
        local level = self.anatomy.levels[chain.id];
        for j = 1, level - 1 do
            self.hiddenZones["w_" .. chain.parts[j]] = true;
        end
    end
    self:placeRigorZone();
    self:placeEyesZone();
end

function TCA_ExamUI:placeRigorZone()
    local W = TCA.Wounds;
    for i = 1, #W.LIMB_CHAINS do
        local chain = W.LIMB_CHAINS[i];
        local level = self.anatomy.levels[chain.id];
        if level < #chain.parts then
            local target = TCA_ExamUI.ZONES["w_" .. chain.parts[level + 1]];
            if i > 1 or level > 0 then
                self.zonePos.arm = { x = target.x, y = target.y };
            end
            if chain.kind == "leg" then
                self.zoneLabels.arm = "IGUI_TCA_ExamZone_leg";
                self.zoneHints.arm = "IGUI_TCA_ExamHint_leg";
            elseif level > 0 then
                self.zoneHints.arm = "IGUI_TCA_ExamHint_armStump";
            end
            return;
        end
    end
    self.noMarker.arm = "IGUI_TCA_ExamRigorNoLimb";
end

function TCA_ExamUI:placeEyesZone()
    local zone = TCA_ExamUI.ZONES.eyes;
    if self.anatomy.eyeL and self.anatomy.eyeR then
        self.noMarker.eyes = "IGUI_TCA_ExamEyesNone";
    elseif self.anatomy.eyeL then
        self.zonePos.eyes = { x = -zone.x, y = zone.y };
    end
end

function TCA_ExamUI:applyAnatomyTexts()
    for id, key in pairs(self.noMarker) do
        if not self.texts[id] then
            self.texts[id] = getText(key);
        end
    end
end

function TCA_ExamUI:getZoneLabel(id)
    return getText((self.zoneLabels and self.zoneLabels[id]) or ("IGUI_TCA_ExamZone_" .. id));
end

function TCA_ExamUI:getZoneHint(id)
    return getText((self.zoneHints and self.zoneHints[id]) or ("IGUI_TCA_ExamHint_" .. id));
end

function TCA_ExamUI:getZoneIds()
    local list = TCA_ExamUI.ORDER;
    if self.mode == "wounds" then
        list = TCA.Wounds.REGION_ORDER;
    end
    if not self.hiddenZones then
        return list;
    end
    local ids = {};
    for _, id in ipairs(list) do
        if not self.hiddenZones[id] then
            table.insert(ids, id);
        end
    end
    return ids;
end

function TCA_ExamUI:getMarkerIds()
    local ids = {};
    for _, id in ipairs(self:getZoneIds()) do
        if not (self.noMarker and self.noMarker[id]) then
            table.insert(ids, id);
        end
    end
    return ids;
end

function TCA_ExamUI:getHoldMs(zone)
    if zone == "temp" and self.digitalThermometer then
        return TCA_ExamUI.DIGITAL_TEMP_HOLD_MS;
    end
    return TCA_ExamUI.HOLD_MS[zone] or TCA_ExamUI.WOUND_HOLD_MS;
end

function TCA_ExamUI:updateThermometer()
    local item = TCA.Exam.findThermometer(self.character);
    self.hasThermometer = item ~= nil;
    self.digitalThermometer = TCA.Exam.isDigitalThermometer(item);
end

function TCA_ExamUI:refreshTools()
    local now = getTimestampMs();
    if now - self.toolCheckTime < TCA_ExamUI.TOOL_CHECK_MS then
        return;
    end
    self.toolCheckTime = now;
    self:updateThermometer();
end

function TCA_ExamUI:isOnFlank(x, y)
    local zone = TCA_ExamUI.ZONES.livor;
    local bx, by = self:toBody(x, y);
    if by < zone.y - TCA_ExamUI.LIVOR_UP or by > zone.y + TCA_ExamUI.LIVOR_DOWN then
        return false;
    end
    return math.abs(math.abs(bx) - math.abs(zone.x)) <= TCA_ExamUI.LIVOR_HALF_W;
end

function TCA_ExamUI:isInView(x, y)
    return x >= self.viewX and y >= self.viewY and x < self.viewX + self.viewW and y < self.viewY + self.viewH;
end

function TCA_ExamUI:getZoneScreen(id)
    local zone = TCA_ExamUI.ZONES[id];
    if self.zonePos and self.zonePos[id] and not self.editMode then
        zone = self.zonePos[id];
    end
    return self:toScreen(zone.x, zone.y);
end

function TCA_ExamUI:getZoneAt(x, y)
    if not self:isInView(x, y) then
        return nil;
    end
    for _, id in ipairs(self:getMarkerIds()) do
        local zone = TCA_ExamUI.ZONES[id];
        local zx, zy = self:getZoneScreen(id);
        if dist(x, y, zx, zy) <= zone.radius * self.k then
            return id;
        end
    end
    if self.mode ~= "wounds" and self:isOnFlank(x, y) then
        return "livor";
    end
    return nil;
end

function TCA_ExamUI:isPull(id)
    return TCA_ExamUI.PULL[id] ~= nil;
end

function TCA_ExamUI:onMouseDown(x, y)
    if TCA_UIDrag.begin(self, x, y) then
        return true;
    end
    if self:editMouseDown(x, y) then
        return true;
    end
    if self:scrollMouseDown(x, y) then
        return true;
    end
    if self:barMouseDown(x, y) then
        return true;
    end
    local zone = self:getZoneAt(x, y);
    if not zone then
        return true;
    end
    if zone == "temp" and not self.hasThermometer then
        self.warnTime = getTimestampMs();
        return true;
    end
    local press = {};
    press.zone = zone;
    press.x = x;
    press.y = y;
    press.time = getTimestampMs();
    press.progress = 0;
    press.pull = 0;
    press.reached = false;
    self.press = press;
    return true;
end

function TCA_ExamUI:releasePress()
    local press = self.press;
    self.press = nil;
    if press and self:isPull(press.zone) and press.reached then
        self:completeZone(press.zone, press.x, press.y);
    end
end

function TCA_ExamUI:onMouseUp(x, y)
    TCA_UIDrag.finish(self, "exam");
    self.dragHandle = nil;
    self.scrollDrag = nil;
    self:releaseEdit();
    self:releasePress();
    return true;
end

function TCA_ExamUI:onMouseUpOutside(x, y)
    TCA_UIDrag.finish(self, "exam");
    self.dragHandle = nil;
    self.scrollDrag = nil;
    self:releaseEdit();
    self:releasePress();
    return true;
end

function TCA_ExamUI:updatePress()
    local press = self.press;
    if not press then
        return;
    end
    local mx = self:getMouseX();
    local my = self:getMouseY();
    if self:isPull(press.zone) then
        local maxPull = TCA_ExamUI.PULL[press.zone] * self.k;
        local pull = my - press.y;
        if press.zone == "arm" then
            pull = press.y - my;
        end
        press.pull = clamp(pull, 0, maxPull);
        press.progress = press.pull / maxPull;
        if press.progress >= TCA_ExamUI.PULL_DONE then
            press.reached = true;
        end
        return;
    end
    if dist(mx, my, press.x, press.y) > TCA_ExamUI.HOLD_TOLERANCE * self.k then
        self.press = nil;
        return;
    end
    if press.zone == "temp" and not self.hasThermometer then
        self.press = nil;
        return;
    end
    press.progress = clamp((getTimestampMs() - press.time) / self:getHoldMs(press.zone), 0, 1);
    if press.progress >= 1 then
        self.press = nil;
        self:completeZone(press.zone, press.x, press.y);
    end
end

function TCA_ExamUI:loadObservations()
    local E = TCA.Exam;
    local mine = E.getObservations(self.body, self.observerKey);
    if not mine then
        return;
    end
    for _, zone in ipairs(TCA_ExamUI.ORDER) do
        self:loadObservation(mine, zone);
    end
    for _, zone in ipairs(TCA.Wounds.REGION_ORDER) do
        self:loadObservation(mine, zone);
    end
end

function TCA_ExamUI:loadObservation(mine, zone)
    local E = TCA.Exam;
    local obs = E.decodeObservation(zone, mine[zone]);
    if not obs then
        return;
    end
    self.texts[zone] = E.getObservationText(zone, obs, self.body);
    self.observedAt[zone] = obs.time;
    self.done[zone] = true;
    if TCA.Wounds.isRegion(zone) then
        self.woundLevels[zone] = obs.level;
    end
end

function TCA_ExamUI:saveObservation(zone, reading)
    local E = TCA.Exam;
    local now = getGameTime():getWorldAgeHours();
    local data = E.encodeObservation(zone, reading, self.level, now);
    if not data then
        return;
    end
    self.observedAt[zone] = now;
    E.storeObservation(self.body, self.observerKey, zone, data);
    if isClient() then
        TCA_Client.sendExamObservation(self.character, self.body, zone, data, self.observerKey);
    end
end

function TCA_ExamUI:hasFoundBite()
    for zone, level in pairs(self.woundLevels) do
        if TCA.Wounds.regionShowsBite(self.body, zone, level) then
            return true;
        end
    end
    return false;
end

function TCA_ExamUI:getObservationAge(zone)
    local t = self.observedAt[zone];
    if not t then
        return nil;
    end
    local age = getGameTime():getWorldAgeHours() - t;
    if age < TCA.Exam.OBS_AGE_SHOW then
        return nil;
    end
    return age;
end

function TCA_ExamUI:completeZone(zone, x, y)
    local E = TCA.Exam;
    local reading = nil;
    if zone == "temp" then
        reading = E.readTemperature(self.body, self.level);
        self.texts.temp = E.getTempText(reading);
        if self.digitalThermometer then
            E.requestThermometerUse(self.character);
            self.toolCheckTime = 0;
        end
    elseif zone == "jaw" or zone == "arm" then
        reading = self.values[zone];
        self.texts[zone] = getText(E.getRigorKey(self.values[zone], self.level));
    elseif zone == "livor" then
        reading = self.values.livor;
        self.texts.livor = E.getLivorText(self.values.livor, self.level);
        local blanch = {};
        blanch.x = x;
        blanch.y = y;
        blanch.time = getTimestampMs();
        self.blanch = blanch;
    elseif zone == "decomp" then
        reading = self.values.decomp;
        self.texts.decomp = E.getDecompText(self.values.decomp);
    elseif zone == "eyes" then
        reading = self.values.eyes;
        self.texts.eyes = E.getEyesText(self.values.eyes);
    elseif zone == "insects" then
        reading = self.values.insects;
        self.texts.insects = E.getInsectsText(self.values.insects);
    elseif TCA.Wounds.isRegion(zone) then
        reading = 0;
        self.woundLevels[zone] = self.level;
        self.texts[zone] = TCA.Wounds.getRegionText(self.body, zone, self.level);
    end
    self.done[zone] = true;
    if reading ~= nil then
        self:saveObservation(zone, reading);
    end
end

function TCA_ExamUI:barMouseDown(x, y)
    if self.result then
        return false;
    end
    local grab = TCA_ExamUI.BAR_GRAB * self.k;
    if y < self.barY - grab or y > self.barY + self.barH + grab then
        return false;
    end
    if x < self.barX1 - grab or x > self.barX2 + grab then
        return false;
    end
    local minX = self:posToBarX(self.minPos);
    local maxX = self:posToBarX(self.maxPos);
    if math.abs(x - minX) <= math.abs(x - maxX) and x <= maxX then
        self.dragHandle = "min";
    else
        self.dragHandle = "max";
    end
    self:updateDrag();
    return true;
end

function TCA_ExamUI:posToBarX(pos)
    return self.barX1 + (self.barX2 - self.barX1) * pos;
end

function TCA_ExamUI:updateDrag()
    if not self.dragHandle then
        return;
    end
    local pos = clamp((self:getMouseX() - self.barX1) / (self.barX2 - self.barX1), 0, 1);
    if self.dragHandle == "min" then
        self.minPos = math.min(pos, self.maxPos - TCA_ExamUI.HANDLE_GAP);
        self.minPos = math.max(self.minPos, 0);
    else
        self.maxPos = math.max(pos, self.minPos + TCA_ExamUI.HANDLE_GAP);
        self.maxPos = math.min(self.maxPos, 1);
    end
end

function TCA_ExamUI:getHoverZone()
    if self.press then
        return self.press.zone;
    end
    return self:getZoneAt(self:getMouseX(), self:getMouseY());
end

function TCA_ExamUI:getInstructionText()
    local zone = self:getHoverZone();
    if zone == "temp" and not self.hasThermometer then
        return getText("IGUI_TCA_ExamNeedThermo"), RED;
    end
    if zone then
        return self:getZoneLabel(zone) .. " : " .. self:getZoneHint(zone), WHITE;
    end
    if getTimestampMs() - self.warnTime < TCA_ExamUI.WARN_MS then
        return getText("IGUI_TCA_ExamNeedThermo"), RED;
    end
    return getText("IGUI_TCA_ExamInstr"), GREY;
end

function TCA_ExamUI:drawWrapped(text, x, y, maxW, c)
    local lines = TCA_ExamUI.wrapText(self.fontSmall, text, maxW);
    for _, line in ipairs(lines) do
        self:drawText(line, x, y, c.r, c.g, c.b, 1, self.fontSmall);
        y = y + self.smallH;
    end
    return y;
end

function TCA_ExamUI:drawGuide(x, y, maxW)
    local startY = y;
    local k = self.k;
    local K = TCA.Knowledge;
    for t = 1, #K.TIERS do
        local tier = K.TIERS[t];
        local known = K.hasTier(self.character, tier);
        local title = getText("IGUI_TCA_ExamGuideTier" .. tostring(t));
        if known then
            y = self:drawWrapped(title, x, y, maxW, GUIDE_TITLE);
            y = y + 2 * k;
            for _, index in ipairs(tier.lines) do
                y = self:drawWrapped(getText("IGUI_TCA_ExamGuide" .. tostring(index)), x + 10 * k, y, maxW - 10 * k, GUIDE_TEXT);
                y = y + 5 * k;
            end
        else
            y = self:drawWrapped(title, x, y, maxW, GREY);
            y = y + 2 * k;
            local bookName = getItemNameFromFullType(tier.book);
            y = self:drawWrapped(getText("IGUI_TCA_ExamGuideLocked", bookName, tier.level), x + 10 * k, y, maxW - 10 * k, GREY);
            y = y + 5 * k;
        end
        y = y + 6 * k;
    end
    return y - startY;
end

function TCA_ExamUI:drawNotesContent(x, y, maxW)
    local startY = y;
    local k = self.k;
    if self.mode == "guide" then
        return self:drawGuide(x, y, maxW);
    end
    if self.mode == "wounds" and self:hasFoundBite() then
        local warningKey = "IGUI_TCA_WoundBiteWarningSafe";
        if TCA_OrganFood.canInfect() then
            warningKey = "IGUI_TCA_WoundBiteWarning";
        end
        y = self:drawWrapped(getText(warningKey), x, y, maxW, RED);
        y = y + 8 * k;
    end
    for _, id in ipairs(self:getZoneIds()) do
        self:drawText(self:getZoneLabel(id), x, y, 0.95, 0.85, 0.6, 1, self.fontSmall);
        y = y + self.smallH + 2 * k;
        local text = self.texts[id];
        local c = WHITE;
        if not text then
            text = getText("IGUI_TCA_ExamNotDone");
            c = GREY;
        end
        local lines = TCA_ExamUI.wrapText(self.fontSmall, text, maxW - 10 * k);
        for _, line in ipairs(lines) do
            self:drawText(line, x + 10 * k, y, c.r, c.g, c.b, 1, self.fontSmall);
            y = y + self.smallH;
        end
        local age = self:getObservationAge(id);
        if age then
            y = self:drawWrapped(getText("IGUI_TCA_ExamObservedAgo", TCA.Exam.formatHours(age)), x + 10 * k, y, maxW - 10 * k, GREY);
        end
        y = y + 8 * k;
    end
    if TCA_Client.isDebug() then
        y = y + self:drawDebug(x, y, maxW);
    end
    return y - startY;
end

function TCA_ExamUI:drawNotes()
    self:drawRect(self.notesX, self.notesY, self.notesW, self.notesH, 0.6, PANEL_BG.r, PANEL_BG.g, PANEL_BG.b);
    self:drawRectBorder(self.notesX, self.notesY, self.notesW, self.notesH, 1, BORDER.r, BORDER.g, BORDER.b);
    local k = self.k;
    local x = self.notesX + 10 * k;
    local title = getText("IGUI_TCA_ExamNotes");
    if self.mode == "guide" then
        title = getText("IGUI_TCA_ExamGuideTitle");
    elseif self.mode == "wounds" then
        title = getText("IGUI_TCA_ExamWoundsTitle");
    end
    self:drawText(title, x, self.notesY + 8 * k, 1, 1, 1, 1, self.fontMedium);

    local top = self:getNotesContentTop();
    local height = self:getNotesContentH();
    local maxW = self.notesW - 24 * k - TCA_ExamUI.SCROLL_W * k;
    self:setScroll(self.scroll);
    self:setStencilRect(self.notesX + 1, top, self.notesW - 2, height);
    self.contentH = self:drawNotesContent(x, top - self.scroll, maxW);
    self:clearStencilRect();
    self:setScroll(self.scroll);

    local thumb = self:getScrollThumb();
    if thumb then
        self:drawRect(thumb.x, thumb.top, thumb.w, thumb.trackH, 0.5, 0.15, 0.15, 0.17);
        self:drawRect(thumb.x, thumb.y, thumb.w, thumb.h, 0.9, 0.55, 0.55, 0.58);
    end
end

function TCA_ExamUI:drawDebug(x, y, maxW)
    local startY = y;
    local D = TCA.DeathTime;
    local C = TCA.Cold;
    local truth = D.getHoursSinceDeath(self.body);
    local text = getText("IGUI_TCA_ExamDebug", TCA.Exam.formatHours(truth), string.format("%.1f", C.getColdHours(self.body)), TCA.Exam.formatHours(C.getEffectiveHours(self.body, C.DECAY_FACTOR)));
    local E = TCA.Exam;
    text = text .. string.format(" / eyes %d / insects %d (rate %.2f, maggots %d)", E.getEyesStage(self.body), E.getInsectStage(self.body), E.getInsectRate(self.body), E.getHarvestCount(self.body));
    local lines = TCA_ExamUI.wrapText(self.fontSmall, text, maxW);
    for _, line in ipairs(lines) do
        self:drawText(line, x, y, 1, 0.85, 0.3, 1, self.fontSmall);
        y = y + self.smallH;
    end
    return y - startY;
end

function TCA_ExamUI:drawTimeline()
    local E = TCA.Exam;
    local lo = E.posToHours(self.minPos);
    local hi = E.posToHours(self.maxPos);
    local text = getText("IGUI_TCA_ExamRange", E.formatHours(lo), E.formatHours(hi));
    local c = WHITE;
    if not self.result and self:isRangeTooWide() then
        text = text .. " " .. getText("IGUI_TCA_ExamTooWideTag");
        c = RED;
    end
    if self.result then
        local verdict = getText("IGUI_TCA_ExamGivenWrong");
        c = RED;
        if self.result.ok then
            verdict = getText("IGUI_TCA_ExamGivenRight");
            c = GREEN;
        end
        text = getText("IGUI_TCA_ExamGiven", E.formatHours(self.result.minHours), E.formatHours(self.result.maxHours), verdict);
    end
    self:drawTextCentre(text, self.width / 2, self.rangeY, c.r, c.g, c.b, 1, self.fontSmall);

    local barW = self.barX2 - self.barX1;
    self:drawRect(self.barX1, self.barY, barW, self.barH, 0.8, 0.18, 0.18, 0.2);
    local x1 = self:posToBarX(self.minPos);
    local x2 = self:posToBarX(self.maxPos);
    local sel = GREEN;
    if self.result then
        sel = GREY;
    end
    self:drawRect(x1, self.barY, x2 - x1, self.barH, 0.85, sel.r, sel.g, sel.b);
    self:drawRectBorder(self.barX1, self.barY, barW, self.barH, 1, BORDER.r, BORDER.g, BORDER.b);

    for _, hours in ipairs(E.TICKS) do
        local tx = self:posToBarX(E.hoursToPos(hours));
        self:drawRect(tx, self.barY + self.barH, math.max(1, self.k), 5 * self.k, 0.8, 0.7, 0.7, 0.7);
        self:drawTextCentre(E.formatHours(hours), tx, self.barY + self.barH + 6 * self.k, 0.7, 0.7, 0.7, 1, self.fontSmall);
    end

    local handleC = WHITE;
    if self.result then
        handleC = GREY;
    end
    local k = self.k;
    self:drawRect(x1 - 3 * k, self.barY - 6 * k, 6 * k, self.barH + 12 * k, 1, handleC.r, handleC.g, handleC.b);
    self:drawRect(x2 - 3 * k, self.barY - 6 * k, 6 * k, self.barH + 12 * k, 1, handleC.r, handleC.g, handleC.b);
end

function TCA_ExamUI:prerender()
    TCA_UIDrag.update(self);
    ISPanel.prerender(self);
    self:refreshTools();
    self:updatePress();
    self:updateDrag();
    self:updateScrollDrag();
    self:updateEdit();
    self:updateConcludeButton();

    self:drawTextCentre(getText("IGUI_TCA_ExamTitle"), self.width / 2, self.titleY, 1, 1, 1, 1, self.fontMedium);
    local instr, c = self:getInstructionText();
    self:drawTextCentre(instr, self.width / 2, self.instructionsY, c.r, c.g, c.b, 1, self.fontSmall);

    self:drawRect(self.viewX, self.viewY, self.viewW, self.viewH, 1, 0.12, 0.13, 0.14);
    if not self.model then
        self:setStencilRect(self.viewX, self.viewY, self.viewW, self.viewH);
        TCA_BodyRenderer.drawBody(self, false);
        self:clearStencilRect();
    end

    self:drawNotes();
    self:drawCauseStrip();
    self:drawTimeline();
end

function TCA_ExamUI:drawLivorPatch()
    local visible = self.values.livor.visible;
    if visible <= 0.02 then
        return;
    end
    local zone = TCA_ExamUI.ZONES.livor;
    local radius = TCA_ExamUI.LIVOR_RADIUS * self.scale;
    local edge = math.abs(zone.x);
    local by = zone.y - TCA_ExamUI.LIVOR_UP;
    while by <= zone.y + TCA_ExamUI.LIVOR_DOWN do
        local sx1, sy1 = self:toScreen(-edge, by);
        local sx2, sy2 = self:toScreen(edge, by);
        self:fillCircleScreen(sx1, sy1, radius, LIVOR, 0.35 * visible);
        self:fillCircleScreen(sx2, sy2, radius, LIVOR, 0.35 * visible);
        by = by + TCA_ExamUI.LIVOR_STEP;
    end
    local blanch = self.blanch;
    if not blanch then
        return;
    end
    local elapsed = getTimestampMs() - blanch.time;
    if elapsed > TCA_ExamUI.BLANCH_SHOW_MS then
        self.blanch = nil;
        return;
    end
    local fade = 1 - elapsed / TCA_ExamUI.BLANCH_SHOW_MS;
    self:fillCircleScreen(blanch.x, blanch.y, 5 * self.scale, BLANCH, 0.75 * self.values.livor.blanch * visible * fade);
end

function TCA_ExamUI:getZoneColor(id, hovered)
    if id == "temp" and not self.hasThermometer then
        return RED, 0.5;
    end
    if self.done[id] then
        if hovered then
            return WHITE, 0.9;
        end
        return WHITE, 0.45;
    end
    local pulse = 0.55 + 0.35 * math.sin(getTimestampMs() / 250);
    if hovered then
        pulse = 1;
    end
    return GREEN, pulse;
end

function TCA_ExamUI:drawZones()
    local hover = self:getHoverZone();
    for _, id in ipairs(self:getMarkerIds()) do
        local pressed = self.press and self.press.zone == id and self:isPull(id);
        if not pressed then
            local zx, zy = self:getZoneScreen(id);
            local c, a = self:getZoneColor(id, hover == id);
            local zone = TCA_ExamUI.ZONES[id];
            self:drawArc(zx, zy, zone.radius * 0.6 * self.k, 2 * self.k, 1, c, a);
            self:fillCircleScreen(zx, zy, 2 * self.k, c, a);
        end
    end
end

function TCA_ExamUI:drawThermometer(x, y)
    local k = self.k;
    local tx = x - 34 * k;
    local ty = y - 26 * k;
    self:thickLineScreen(x, y, tx, ty, 5 * k, GREY, 1);
    self:thickLineScreen(x, y, tx, ty, 3 * k, GLASS, 1);
    self:fillCircleScreen(x, y, 4 * k, RED, 1);
end

function TCA_ExamUI:drawPress()
    local press = self.press;
    if not press then
        return;
    end
    if self:isPull(press.zone) then
        local zx, zy = self:getZoneScreen(press.zone);
        local resist = 1 - TCA_ExamUI.RIGOR_RESIST * self.values[press.zone];
        local moved = press.pull * resist;
        local px = zx;
        local py = zy + moved;
        if press.zone == "arm" then
            py = zy - moved;
        end
        local mx = self:getMouseX();
        local my = self:getMouseY();
        local tension = 0;
        if press.pull > 0.5 then
            tension = clamp((press.pull - moved) / press.pull, 0, 1);
        end
        self:thickLineScreen(px, py, mx, my, 2 * self.k, ORANGE, 0.3 + 0.6 * tension);
        self:fillCircleScreen(px, py, 6 * self.k, WHITE, 0.9);
        local c = GREEN;
        if not press.reached then
            c = WHITE;
        end
        self:drawArc(px, py, 10 * self.k, 2 * self.k, press.progress, c, 0.9);
        return;
    end
    if press.zone == "temp" then
        self:drawThermometer(press.x, press.y);
    else
        self:fillCircleScreen(press.x, press.y, 5 * self.k, WHITE, 0.5);
    end
    self:drawArc(press.x, press.y, 12 * self.k, 3 * self.k, press.progress, GREEN, 0.9);
end

function TCA_ExamUI:getTooltipZone()
    if self.press or self.editMode or self.dragHandle or self.scrollDrag then
        return nil;
    end
    local zone = self:getZoneAt(self:getMouseX(), self:getMouseY());
    if not zone or not self.done[zone] or not self.texts[zone] then
        return nil;
    end
    return zone;
end

function TCA_ExamUI:drawZoneTooltip()
    local zone = self:getTooltipZone();
    if not zone then
        return;
    end
    local tm = getTextManager();
    local k = self.k;
    local pad = TCA_ExamUI.TOOLTIP_PAD * k;
    local tipW = TCA_ExamUI.TOOLTIP_W * k;
    local title = self:getZoneLabel(zone);
    local lines = TCA_ExamUI.wrapText(self.fontSmall, self.texts[zone], tipW);
    local ageLines = {};
    local age = self:getObservationAge(zone);
    if age then
        ageLines = TCA_ExamUI.wrapText(self.fontSmall, getText("IGUI_TCA_ExamObservedAgo", TCA.Exam.formatHours(age)), tipW);
    end
    local w = tm:MeasureStringX(self.fontSmall, title);
    for _, line in ipairs(lines) do
        w = math.max(w, tm:MeasureStringX(self.fontSmall, line));
    end
    for _, line in ipairs(ageLines) do
        w = math.max(w, tm:MeasureStringX(self.fontSmall, line));
    end
    w = w + pad * 2;
    local h = pad * 2 + self.smallH * (1 + #lines + #ageLines) + 2 * k;
    local mx = self:getMouseX();
    local my = self:getMouseY();
    local x = mx + 18 * k;
    local y = my + 18 * k;
    if x + w > self.width - 4 * k then
        x = mx - w - 12 * k;
    end
    if y + h > self.height - 4 * k then
        y = self.height - 4 * k - h;
    end
    x = math.max(4 * k, x);
    y = math.max(4 * k, y);
    self:drawRect(x, y, w, h, 0.94, PANEL_BG.r, PANEL_BG.g, PANEL_BG.b);
    self:drawRectBorder(x, y, w, h, 1, BORDER.r, BORDER.g, BORDER.b);
    local ty = y + pad;
    self:drawText(title, x + pad, ty, GUIDE_TITLE.r, GUIDE_TITLE.g, GUIDE_TITLE.b, 1, self.fontSmall);
    ty = ty + self.smallH + 2 * k;
    for _, line in ipairs(lines) do
        self:drawText(line, x + pad, ty, WHITE.r, WHITE.g, WHITE.b, 1, self.fontSmall);
        ty = ty + self.smallH;
    end
    for _, line in ipairs(ageLines) do
        self:drawText(line, x + pad, ty, GREY.r, GREY.g, GREY.b, 1, self.fontSmall);
        ty = ty + self.smallH;
    end
end

function TCA_ExamUI:render()
    ISPanel.render(self);
    self:setStencilRect(self.viewX, self.viewY, self.viewW, self.viewH);
    self:drawLivorPatch();
    self:drawZones();
    self:drawPress();
    self:drawEditLabels();
    self:clearStencilRect();
    self:drawRectBorder(self.viewX, self.viewY, self.viewW, self.viewH, 1, BORDER.r, BORDER.g, BORDER.b);
    self:drawZoneTooltip();
end

function TCA_ExamUI:hideButtonTooltip(button)
    if button and button.tooltipUI and button.tooltipUI:getIsVisible() then
        button.tooltipUI:setVisible(false);
        button.tooltipUI:removeFromUIManager();
    end
end

function TCA_ExamUI:collectResult()
    local result = {};
    result.conclude = self.conclude and self.result == nil;
    result.minHours = TCA.Exam.posToHours(self.minPos);
    result.maxHours = TCA.Exam.posToHours(self.maxPos);
    result.observer = self.observerKey;
    return result;
end

function TCA_ExamUI:closeSilently()
    self:hideButtonTooltip(self.concludeButton);
    self:setVisible(false);
    self:removeFromUIManager();
    if TCA_ExamUI.instance == self then
        TCA_ExamUI.instance = nil;
    end
end

function TCA_ExamUI.open(character, body)
    if TCA_ExamUI.instance then
        TCA_ExamUI.instance:closeSilently();
    end
    local k = TCA_UIScale.get(TCA_ExamUI.WIDTH, TCA_ExamUI.HEIGHT);
    local w = math.floor(TCA_ExamUI.WIDTH * k);
    local h = math.floor(TCA_ExamUI.HEIGHT * k);
    local x = (getCore():getScreenWidth() - w) / 2;
    local y = (getCore():getScreenHeight() - h) / 2;
    local ui = TCA_ExamUI:new(x, y, w, h, character, body);
    ui.uiScale = k;
    ui:initialise();
    ui:instantiate();
    TCA_UIDrag.restore(ui, "exam");
    ui:addToUIManager();
    TCA_ExamUI.instance = ui;
    return ui;
end

function TCA_ExamUI:new(x, y, width, height, character, body)
    local o = ISPanel.new(self, x, y, width, height);
    o.character = character;
    o.body = body;
    o.backgroundColor = { r = 0.08, g = 0.08, b = 0.09, a = 0.95 };
    o.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 };
    o.moveWithMouse = false;
    return o;
end
