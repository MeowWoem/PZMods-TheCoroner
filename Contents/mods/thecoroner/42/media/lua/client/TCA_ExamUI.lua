require "ISUI/ISPanel";
require "ISUI/ISButton";
require "TCA_Shared";
require "TCA_Exam";
require "TCA_Cold";
require "TCA_BodyRenderer";

TCA_ExamUI = ISPanel:derive("TCA_ExamUI");

TCA_ExamUI.WIDTH = 800;
TCA_ExamUI.HEIGHT = 660;
TCA_ExamUI.VIEW = { x1 = -130, y1 = -20, x2 = 130, y2 = 490 };

TCA_ExamUI.ORDER = { "temp", "jaw", "arm", "livor", "decomp" };
TCA_ExamUI.ZONES = {
    temp = { x = -58, y = 96, radius = 14 },
    jaw = { x = 0, y = 54, radius = 14 },
    arm = { x = 83, y = 292, radius = 14 },
    livor = { x = 47, y = 225, radius = 14 },
    decomp = { x = 0, y = 185, radius = 22 },
};

TCA_ExamUI.HOLD_MS = { temp = 3000, livor = 1500, decomp = 800 };
TCA_ExamUI.HOLD_TOLERANCE = 10;
TCA_ExamUI.PULL = { jaw = 40, arm = 70 };
TCA_ExamUI.PULL_DONE = 0.9;
TCA_ExamUI.RIGOR_RESIST = 0.9;
TCA_ExamUI.BLANCH_SHOW_MS = 5000;
TCA_ExamUI.TOOL_CHECK_MS = 500;
TCA_ExamUI.WARN_MS = 1500;
TCA_ExamUI.LIVOR_INNER = 12;
TCA_ExamUI.LIVOR_OUTER = 2;
TCA_ExamUI.LIVOR_Y1 = 150;
TCA_ExamUI.LIVOR_Y2 = 285;
TCA_ExamUI.BAR_GRAB = 14;
TCA_ExamUI.HANDLE_GAP = 0.01;
TCA_ExamUI.GUIDE_LINES = 9;

local WHITE = { r = 1, g = 1, b = 1 };
local GREEN = { r = 0.2, g = 0.9, b = 0.3 };
local GREY = { r = 0.55, g = 0.55, b = 0.58 };
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
    local tm = getTextManager();
    self.titleH = tm:getFontHeight(UIFont.Medium);
    self.smallH = tm:getFontHeight(UIFont.Small);
    self.titleY = 10;
    self.instructionsY = self.titleY + self.titleH + 4;
    self.viewX = 20;
    self.viewY = self.instructionsY + self.smallH + 12;
    self.viewW = 300;
    self.viewH = self.height - self.viewY - 170;
    self.notesX = self.viewX + self.viewW + 20;
    self.notesY = self.viewY;
    self.notesW = self.width - self.notesX - 20;
    self.notesH = self.viewH;
    self.rangeY = self.viewY + self.viewH + 14;
    self.barY = self.rangeY + self.smallH + 16;
    self.barH = 8;
    self.barX1 = 50;
    self.barX2 = self.width - 50;
    self:setView(TCA_ExamUI.VIEW);

    self.level = E.getLevel(self.character);
    self.values = E.readAll(self.body, self.level);
    self.done = {};
    self.texts = {};
    self.press = nil;
    self.blanch = nil;
    self.warnTime = 0;
    self.showGuide = false;
    self.finished = false;
    self.conclude = false;
    self.dragHandle = nil;
    self.result = E.getResult(self.body);
    self.minPos = 0.3;
    self.maxPos = 0.5;
    if self.result then
        self.minPos = E.hoursToPos(self.result.minHours);
        self.maxPos = E.hoursToPos(self.result.maxHours);
    end
    self.hasThermometer = E.findThermometer(self.character) ~= nil;
    self.toolCheckTime = getTimestampMs();
end

function TCA_ExamUI:createChildren()
    ISPanel.createChildren(self);
    local btnW = 140;
    local btnH = 25;
    local y = self.height - btnH - 12;
    self.closeButton = ISButton:new(self.width / 2 - btnW - 10, y, btnW, btnH, getText("IGUI_TCA_ExamClose"), self, TCA_ExamUI.onCloseClick);
    self.closeButton:initialise();
    self.closeButton:instantiate();
    self:addChild(self.closeButton);

    self.concludeButton = ISButton:new(self.width / 2 + 10, y, btnW, btnH, getText("IGUI_TCA_ExamConclude"), self, TCA_ExamUI.onConcludeClick);
    self.concludeButton:initialise();
    self.concludeButton:instantiate();
    self:addChild(self.concludeButton);
    self.concludeButton:setEnable(self.result == nil);

    local guideW = 120;
    self.guideButton = ISButton:new(self.notesX + self.notesW - guideW - 6, self.notesY + 6, guideW, 20, getText("IGUI_TCA_ExamGuide"), self, TCA_ExamUI.onGuideClick);
    self.guideButton:initialise();
    self.guideButton:instantiate();
    self:addChild(self.guideButton);

    self:createBodyModel();
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

function TCA_ExamUI:onConcludeClick()
    if self.result then
        return;
    end
    self.conclude = true;
    self.finished = true;
end

function TCA_ExamUI:onGuideClick()
    self.showGuide = not self.showGuide;
    if self.showGuide then
        self.guideButton:setTitle(getText("IGUI_TCA_ExamNotes"));
    else
        self.guideButton:setTitle(getText("IGUI_TCA_ExamGuide"));
    end
end

function TCA_ExamUI:refreshTools()
    local now = getTimestampMs();
    if now - self.toolCheckTime < TCA_ExamUI.TOOL_CHECK_MS then
        return;
    end
    self.toolCheckTime = now;
    self.hasThermometer = TCA.Exam.findThermometer(self.character) ~= nil;
end

function TCA_ExamUI.getFlankEdge(by)
    if by < 250 then
        return 62 - 14 * (by - 70) / 180;
    end
    return 48 + 8 * (by - 250) / 40;
end

function TCA_ExamUI:isOnFlank(x, y)
    local bx, by = self:toBody(x, y);
    if by < TCA_ExamUI.LIVOR_Y1 or by > TCA_ExamUI.LIVOR_Y2 then
        return false;
    end
    local edge = TCA_ExamUI.getFlankEdge(by);
    local ax = math.abs(bx);
    return ax >= edge - TCA_ExamUI.LIVOR_INNER and ax <= edge + TCA_ExamUI.LIVOR_OUTER;
end

function TCA_ExamUI:isInView(x, y)
    return x >= self.viewX and y >= self.viewY and x < self.viewX + self.viewW and y < self.viewY + self.viewH;
end

function TCA_ExamUI:getZoneScreen(id)
    local zone = TCA_ExamUI.ZONES[id];
    return self:toScreen(zone.x, zone.y);
end

function TCA_ExamUI:getZoneAt(x, y)
    if not self:isInView(x, y) then
        return nil;
    end
    for _, id in ipairs(TCA_ExamUI.ORDER) do
        local zone = TCA_ExamUI.ZONES[id];
        local zx, zy = self:getZoneScreen(id);
        if dist(x, y, zx, zy) <= zone.radius then
            return id;
        end
    end
    if self:isOnFlank(x, y) then
        return "livor";
    end
    return nil;
end

function TCA_ExamUI:isPull(id)
    return TCA_ExamUI.PULL[id] ~= nil;
end

function TCA_ExamUI:onMouseDown(x, y)
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
    self.dragHandle = nil;
    self:releasePress();
    return true;
end

function TCA_ExamUI:onMouseUpOutside(x, y)
    self.dragHandle = nil;
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
        local maxPull = TCA_ExamUI.PULL[press.zone];
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
    if dist(mx, my, press.x, press.y) > TCA_ExamUI.HOLD_TOLERANCE then
        self.press = nil;
        return;
    end
    if press.zone == "temp" and not self.hasThermometer then
        self.press = nil;
        return;
    end
    press.progress = clamp((getTimestampMs() - press.time) / TCA_ExamUI.HOLD_MS[press.zone], 0, 1);
    if press.progress >= 1 then
        self.press = nil;
        self:completeZone(press.zone, press.x, press.y);
    end
end

function TCA_ExamUI:completeZone(zone, x, y)
    local E = TCA.Exam;
    if zone == "temp" then
        self.texts.temp = E.getTempText(E.readTemperature(self.body, self.level));
    elseif zone == "jaw" or zone == "arm" then
        self.texts[zone] = getText(E.getRigorKey(self.values[zone], self.level));
    elseif zone == "livor" then
        self.texts.livor = E.getLivorText(self.values.livor, self.level);
        local blanch = {};
        blanch.x = x;
        blanch.y = y;
        blanch.time = getTimestampMs();
        self.blanch = blanch;
    elseif zone == "decomp" then
        self.texts.decomp = E.getDecompText(self.values.decomp);
    end
    self.done[zone] = true;
end

function TCA_ExamUI:barMouseDown(x, y)
    if self.result then
        return false;
    end
    if y < self.barY - TCA_ExamUI.BAR_GRAB or y > self.barY + self.barH + TCA_ExamUI.BAR_GRAB then
        return false;
    end
    if x < self.barX1 - TCA_ExamUI.BAR_GRAB or x > self.barX2 + TCA_ExamUI.BAR_GRAB then
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
        return getText("IGUI_TCA_ExamZone_" .. zone) .. " : " .. getText("IGUI_TCA_ExamHint_" .. zone), WHITE;
    end
    if getTimestampMs() - self.warnTime < TCA_ExamUI.WARN_MS then
        return getText("IGUI_TCA_ExamNeedThermo"), RED;
    end
    return getText("IGUI_TCA_ExamInstr"), GREY;
end

function TCA_ExamUI:drawNotes()
    self:drawRect(self.notesX, self.notesY, self.notesW, self.notesH, 0.6, PANEL_BG.r, PANEL_BG.g, PANEL_BG.b);
    self:drawRectBorder(self.notesX, self.notesY, self.notesW, self.notesH, 1, BORDER.r, BORDER.g, BORDER.b);
    local x = self.notesX + 10;
    local y = self.notesY + 8;
    local maxW = self.notesW - 20;
    if self.showGuide then
        self:drawText(getText("IGUI_TCA_ExamGuideTitle"), x, y, 1, 1, 1, 1, UIFont.Medium);
        y = y + self.titleH + 8;
        for i = 1, TCA_ExamUI.GUIDE_LINES do
            local lines = TCA_ExamUI.wrapText(UIFont.Small, getText("IGUI_TCA_ExamGuide" .. tostring(i)), maxW);
            for _, line in ipairs(lines) do
                self:drawText(line, x, y, 0.85, 0.85, 0.85, 1, UIFont.Small);
                y = y + self.smallH;
            end
            y = y + 5;
        end
        return;
    end
    self:drawText(getText("IGUI_TCA_ExamNotes"), x, y, 1, 1, 1, 1, UIFont.Medium);
    y = y + self.titleH + 10;
    for _, id in ipairs(TCA_ExamUI.ORDER) do
        self:drawText(getText("IGUI_TCA_ExamZone_" .. id), x, y, 0.95, 0.85, 0.6, 1, UIFont.Small);
        y = y + self.smallH + 2;
        local text = self.texts[id];
        local c = WHITE;
        if not text then
            text = getText("IGUI_TCA_ExamNotDone");
            c = GREY;
        end
        local lines = TCA_ExamUI.wrapText(UIFont.Small, text, maxW - 10);
        for _, line in ipairs(lines) do
            self:drawText(line, x + 10, y, c.r, c.g, c.b, 1, UIFont.Small);
            y = y + self.smallH;
        end
        y = y + 8;
    end
    if TCA_Client.isDebug() then
        self:drawDebug(x, self.notesY + self.notesH - self.smallH * 2 - 8, maxW);
    end
end

function TCA_ExamUI:drawDebug(x, y, maxW)
    local D = TCA.DeathTime;
    local C = TCA.Cold;
    local truth = D.getHoursSinceDeath(self.body);
    local text = getText("IGUI_TCA_ExamDebug", TCA.Exam.formatHours(truth), string.format("%.1f", C.getColdHours(self.body)), TCA.Exam.formatHours(C.getEffectiveHours(self.body, C.DECAY_FACTOR)));
    local lines = TCA_ExamUI.wrapText(UIFont.Small, text, maxW);
    for _, line in ipairs(lines) do
        self:drawText(line, x, y, 1, 0.85, 0.3, 1, UIFont.Small);
        y = y + self.smallH;
    end
end

function TCA_ExamUI:drawTimeline()
    local E = TCA.Exam;
    local lo = E.posToHours(self.minPos);
    local hi = E.posToHours(self.maxPos);
    local text = getText("IGUI_TCA_ExamRange", E.formatHours(lo), E.formatHours(hi));
    local c = WHITE;
    if self.result then
        local verdict = getText("IGUI_TCA_ExamGivenWrong");
        c = RED;
        if self.result.ok then
            verdict = getText("IGUI_TCA_ExamGivenRight");
            c = GREEN;
        end
        text = getText("IGUI_TCA_ExamGiven", E.formatHours(self.result.minHours), E.formatHours(self.result.maxHours), verdict);
    end
    self:drawTextCentre(text, self.width / 2, self.rangeY, c.r, c.g, c.b, 1, UIFont.Small);

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
        self:drawRect(tx, self.barY + self.barH, 1, 5, 0.8, 0.7, 0.7, 0.7);
        self:drawTextCentre(E.formatHours(hours), tx, self.barY + self.barH + 6, 0.7, 0.7, 0.7, 1, UIFont.Small);
    end

    local handleC = WHITE;
    if self.result then
        handleC = GREY;
    end
    self:drawRect(x1 - 3, self.barY - 6, 6, self.barH + 12, 1, handleC.r, handleC.g, handleC.b);
    self:drawRect(x2 - 3, self.barY - 6, 6, self.barH + 12, 1, handleC.r, handleC.g, handleC.b);
end

function TCA_ExamUI:prerender()
    ISPanel.prerender(self);
    self:refreshTools();
    self:updatePress();
    self:updateDrag();

    self:drawTextCentre(getText("IGUI_TCA_ExamTitle"), self.width / 2, self.titleY, 1, 1, 1, 1, UIFont.Medium);
    local instr, c = self:getInstructionText();
    self:drawTextCentre(instr, self.width / 2, self.instructionsY, c.r, c.g, c.b, 1, UIFont.Small);

    self:drawRect(self.viewX, self.viewY, self.viewW, self.viewH, 1, 0.12, 0.13, 0.14);
    if not self.model then
        self:setStencilRect(self.viewX, self.viewY, self.viewW, self.viewH);
        TCA_BodyRenderer.drawBody(self, false);
        self:clearStencilRect();
    end

    self:drawNotes();
    self:drawTimeline();
end

function TCA_ExamUI:drawLivorPatch()
    local visible = self.values.livor.visible;
    if visible <= 0.02 then
        return;
    end
    local radius = 6 * self.scale;
    local by = TCA_ExamUI.LIVOR_Y1;
    while by <= TCA_ExamUI.LIVOR_Y2 do
        local edge = TCA_ExamUI.getFlankEdge(by) - 5;
        local sx1, sy1 = self:toScreen(-edge, by);
        local sx2, sy2 = self:toScreen(edge, by);
        self:fillCircleScreen(sx1, sy1, radius, LIVOR, 0.35 * visible);
        self:fillCircleScreen(sx2, sy2, radius, LIVOR, 0.35 * visible);
        by = by + 8;
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
    for _, id in ipairs(TCA_ExamUI.ORDER) do
        local pressed = self.press and self.press.zone == id and self:isPull(id);
        if not pressed then
            local zx, zy = self:getZoneScreen(id);
            local c, a = self:getZoneColor(id, hover == id);
            local zone = TCA_ExamUI.ZONES[id];
            self:drawArc(zx, zy, zone.radius * 0.6, 2, 1, c, a);
            self:fillCircleScreen(zx, zy, 2, c, a);
        end
    end
end

function TCA_ExamUI:drawThermometer(x, y)
    local tx = x - 34;
    local ty = y - 26;
    self:thickLineScreen(x, y, tx, ty, 5, GREY, 1);
    self:thickLineScreen(x, y, tx, ty, 3, GLASS, 1);
    self:fillCircleScreen(x, y, 4, RED, 1);
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
        self:thickLineScreen(px, py, mx, my, 2, ORANGE, 0.3 + 0.6 * tension);
        self:fillCircleScreen(px, py, 6, WHITE, 0.9);
        local c = GREEN;
        if not press.reached then
            c = WHITE;
        end
        self:drawArc(px, py, 10, 2, press.progress, c, 0.9);
        return;
    end
    if press.zone == "temp" then
        self:drawThermometer(press.x, press.y);
    else
        self:fillCircleScreen(press.x, press.y, 5, WHITE, 0.5);
    end
    self:drawArc(press.x, press.y, 12, 3, press.progress, GREEN, 0.9);
end

function TCA_ExamUI:render()
    ISPanel.render(self);
    self:setStencilRect(self.viewX, self.viewY, self.viewW, self.viewH);
    self:drawLivorPatch();
    self:drawZones();
    self:drawPress();
    self:clearStencilRect();
    self:drawRectBorder(self.viewX, self.viewY, self.viewW, self.viewH, 1, BORDER.r, BORDER.g, BORDER.b);
end

function TCA_ExamUI:collectResult()
    local result = {};
    result.conclude = self.conclude and self.result == nil;
    result.minHours = TCA.Exam.posToHours(self.minPos);
    result.maxHours = TCA.Exam.posToHours(self.maxPos);
    return result;
end

function TCA_ExamUI:closeSilently()
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
    local w = TCA_ExamUI.WIDTH;
    local h = TCA_ExamUI.HEIGHT;
    local x = (getCore():getScreenWidth() - w) / 2;
    local y = (getCore():getScreenHeight() - h) / 2;
    local ui = TCA_ExamUI:new(x, y, w, h, character, body);
    ui:initialise();
    ui:instantiate();
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
