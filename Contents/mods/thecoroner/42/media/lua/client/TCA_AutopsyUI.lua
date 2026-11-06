require "ISUI/ISPanel";
require "ISUI/ISButton";
require "TCA_Autopsy";
require "TCA_BodyRenderer";
require "TCA_Shared";

TCA_AutopsyUI = ISPanel:derive("TCA_AutopsyUI");

TCA_AutopsyUI.WIDTH = 440;
TCA_AutopsyUI.HEIGHT = 680;

TCA_AutopsyUI.VIEW_Y_INCISION = { x1 = -100, y1 = -10, x2 = 100, y2 = 250 };

TCA_AutopsyUI.LAYER_OPENED = "media/textures/torso_step1.png";
TCA_AutopsyUI.LAYER_CHEST = "media/textures/torso_step2.png";
TCA_AutopsyUI.OPEN_FADE_MS = 700;
TCA_AutopsyUI.REMOVE_FADE_MS = 900;

TCA_AutopsyUI.WARN_DIST = 7;
TCA_AutopsyUI.SLIP_DIST = 16;
TCA_AutopsyUI.START_RADIUS = 14;
TCA_AutopsyUI.MAX_STEP = 0.12;
TCA_AutopsyUI.MAX_SPEED = 1.0;
TCA_AutopsyUI.SEGMENT_DONE = 0.98;
TCA_AutopsyUI.TREMOR_BASE = 13;
TCA_AutopsyUI.TREMOR_PER_LEVEL = 1.1;
TCA_AutopsyUI.TREMOR_MIN = 1.5;
TCA_AutopsyUI.PATH_STEP = 1.5;

TCA_AutopsyUI.RIB_PICK_RADIUS = 10;
TCA_AutopsyUI.CUTTER_HOLD_MS = 1500;
TCA_AutopsyUI.CUTTER_HOLD_PER_STR = 80;
TCA_AutopsyUI.CUTTER_HOLD_MIN = 500;
TCA_AutopsyUI.SAW_TRAVEL = 320;
TCA_AutopsyUI.SAW_TRAVEL_PER_STR = 16;
TCA_AutopsyUI.SAW_TRAVEL_MIN = 140;
TCA_AutopsyUI.SAW_STROKE_WARN = 18;
TCA_AutopsyUI.SAW_STROKE_SLIP = 30;
TCA_AutopsyUI.SAW_CUT_CHANCE = 35;

TCA_AutopsyUI.TOOL_CHECK_MS = 500;

TCA_AutopsyUI.HIDE_CURSOR = true;

local CUT = { r = 0.45, g = 0.05, b = 0.05 };
local GAP = { r = 0.12, g = 0.02, b = 0.02 };
local WHITE = { r = 1, g = 1, b = 1 };
local GREEN = { r = 0.2, g = 0.9, b = 0.3 };
local RED = { r = 1, g = 0.2, b = 0.2 };
local BLADE = { r = 0.9, g = 0.9, b = 0.95 };
local STEEL = { r = 0.6, g = 0.62, b = 0.66 };
local HANDLE = { r = 0.25, g = 0.25, b = 0.28 };
local CUTTER_HANDLE = { r = 0.55, g = 0.1, b = 0.08 };
local WARN_TEXT = { r = 1, g = 0.55, b = 0.35 };
local WARN_BG = { r = 0.35, g = 0.05, b = 0.03 };

local function dist(x1, y1, x2, y2)
    local dx = x2 - x1;
    local dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
end

local function project(px, py, ax, ay, bx, by)
    local vx = bx - ax;
    local vy = by - ay;
    local len2 = vx * vx + vy * vy;
    local t = ((px - ax) * vx + (py - ay) * vy) / len2;
    if t < 0 then
        t = 0;
    elseif t > 1 then
        t = 1;
    end
    local qx = ax + vx * t;
    local qy = ay + vy * t;
    return t, dist(px, py, qx, qy);
end

local function clamp01(v)
    if v < 0 then
        return 0;
    end
    if v > 1 then
        return 1;
    end
    return v;
end

function TCA_AutopsyUI:setView(view)
    local vw = self.viewW;
    local vh = self.viewH;
    local fw = view.x2 - view.x1;
    local fh = view.y2 - view.y1;
    self.scale = math.min(vw / fw, vh / fh);
    self.offX = self.viewX + (vw - fw * self.scale) / 2 - view.x1 * self.scale;
    self.offY = self.viewY + (vh - fh * self.scale) / 2 - view.y1 * self.scale;
end

function TCA_AutopsyUI:toScreen(x, y)
    return self.offX + x * self.scale, self.offY + y * self.scale;
end

function TCA_AutopsyUI:toBody(x, y)
    return (x - self.offX) / self.scale, (y - self.offY) / self.scale;
end

function TCA_AutopsyUI:fillCircleScreen(cx, cy, radius, c, a)
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

function TCA_AutopsyUI:thickLineScreen(x1, y1, x2, y2, width, c, a)
    local len = dist(x1, y1, x2, y2);
    if len < 0.01 then
        return;
    end
    local nx = -(y2 - y1) / len * width / 2;
    local ny = (x2 - x1) / len * width / 2;
    self:drawPolygon(nil, x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, c.r, c.g, c.b, a or 1);
end

function TCA_AutopsyUI:initialise()
    ISPanel.initialise(self);
    local A = TCA.Autopsy;

    local titleH = getTextManager():getFontHeight(UIFont.Medium);
    local smallH = getTextManager():getFontHeight(UIFont.Small);
    self.titleY = 10;
    self.instructionsY = self.titleY + titleH + 4;
    self.viewX = 20;
    self.viewY = self.instructionsY + smallH + 12;
    self.viewW = self.width - 40;
    self.viewH = self.height - self.viewY - 95;
    self:setView(TCA_AutopsyUI.VIEW_Y_INCISION);

    self.segments = A.INCISION_Y;

    local state = { segIndex = 1, segProgress = 0, paths = "", accuracy = 0, accSamples = 0 };
    local step = A.STEP_CLOSED;
    local ribsStr = "";
    local body = TCA.findBodyOnTable(self.tableObject);
    if body then
        state = A.getState(body);
        step = A.getStep(body);
        ribsStr = body:getModData()["TCA_A_ribs"];
    end
    self.segIndex = state.segIndex;
    self.segProgress = state.segProgress;
    self.cutPaths = A.decodePaths(state.paths);
    self.complete = self.segIndex > #self.segments;
    if self.complete then
        self.segIndex = #self.segments;
        self.segProgress = 1;
    end
    self.startFraction = A.getFraction(state.segIndex, state.segProgress);

    self.startStep = step;
    self.opened = step >= A.STEP_OPENED;
    self.ribs = A.decodeRibs(ribsStr);
    self.startRibCount = A.countRibs(self.ribs);
    self.ribWork = {};
    for i = 1, #A.RIBS do
        self.ribWork[i] = 0;
    end
    self.ribActive = nil;
    self.ribTool = nil;
    self.ribMode = nil;
    self.toolCheckTime = 0;
    self.hasForceps = false;

    self.layerOpened = getTexture(TCA_AutopsyUI.LAYER_OPENED);
    self.layerChest = getTexture(TCA_AutopsyUI.LAYER_CHEST);

    self.cutting = false;
    self.warn = false;
    self.cuts = 0;
    self.devCount = state.accSamples;
    self.devSum = (1 - state.accuracy) * TCA_AutopsyUI.WARN_DIST * state.accSamples;
    self.flashTime = 0;
    self.finished = false;
    self.lastMouseX = nil;
    self.lastMouseY = nil;
    self.mouseDX = 0;
    self.mouseDY = 0;
    self.speed = 0;
    self.dt = 1;
    self.lastTime = getTimestampMs();
    self.bladeX = 0;
    self.bladeY = 0;
    self.phase = {};
    for i = 1, 6 do
        self.phase[i] = ZombRandFloat(0, 6.28);
    end

    self.stageTime = getTimestampMs();
    if not self.complete then
        self.stage = "incision";
    elseif step < A.STEP_OPENED then
        self.stage = "open";
    elseif step < A.STEP_CHEST then
        self.stage = "ribs";
    else
        self.stage = "done";
    end
end

function TCA_AutopsyUI:createChildren()
    ISPanel.createChildren(self);
    local btnW = 140;
    local btnH = 25;
    local y = self.height - btnH - 12;
    self.finishButton = ISButton:new((self.width - btnW) / 2, y, btnW, btnH, getText("IGUI_TCA_Stop"), self, TCA_AutopsyUI.onFinishClick);
    self.finishButton:initialise();
    self.finishButton:instantiate();
    self:addChild(self.finishButton);

    self.actionButton = ISButton:new((self.width - btnW) / 2, y, btnW, btnH, getText("IGUI_TCA_Open"), self, TCA_AutopsyUI.onActionClick);
    self.actionButton:initialise();
    self.actionButton:instantiate();
    self:addChild(self.actionButton);

    self:createBodyModel();
    self:refreshTools(true);
end

function TCA_AutopsyUI:createBodyModel()
    self.model = nil;
    if not TCA_BodyRenderer.USE_MODEL then
        return;
    end
    local body = TCA.findBodyOnTable(self.tableObject);
    if not body then
        return;
    end
    local model = TCA_BodyRenderer.createModel(self, self.viewX, self.viewY, self.viewW, self.viewH);
    model.forwardTo = self;
    TCA_BodyRenderer.applyAppearance(model, TCA_BodyRenderer.buildDescFromBody(body), true);
    TCA_BodyRenderer.applyCamera(model, self);
    self.model = model;
end

function TCA_AutopsyUI:onFinishClick()
    self.cutting = false;
    self.finished = true;
end

function TCA_AutopsyUI:onActionClick()
    if self.stage ~= "open" then
        return;
    end
    if not TCA.Autopsy.findForceps(self.character) then
        return;
    end
    self.opened = true;
    self:setStage("opening");
end

function TCA_AutopsyUI:setStage(stage)
    self.stage = stage;
    self.stageTime = getTimestampMs();
    self.cutting = false;
    self.ribActive = nil;
    self.warn = false;
    self:refreshTools(true);
end

function TCA_AutopsyUI:getStageFade(durationMs)
    return clamp01((getTimestampMs() - self.stageTime) / durationMs);
end

function TCA_AutopsyUI:refreshTools(force)
    local now = getTimestampMs();
    if not force and now - self.toolCheckTime < TCA_AutopsyUI.TOOL_CHECK_MS then
        return;
    end
    self.toolCheckTime = now;

    if self.stage == "ribs" and not self.cutting then
        self.ribTool, self.ribMode = TCA.Autopsy.findRibTool(self.character);
    end

    local btnW = self.finishButton:getWidth();
    local showAction = self.stage == "open";
    self.actionButton:setVisible(showAction);
    if showAction then
        local forceps = TCA.Autopsy.findForceps(self.character);
        self.hasForceps = forceps ~= nil;
        self.actionButton:setEnable(forceps ~= nil);
        if forceps then
            self.actionButton:setTooltip(getText("IGUI_TCA_Tool", forceps:getDisplayName()));
        else
            self.actionButton:setTooltip(getText("Tooltip_TCA_NeedForceps"));
        end
        self.actionButton:setX(self.width / 2 - btnW - 5);
        self.finishButton:setX(self.width / 2 + 5);
    else
        self.finishButton:setX((self.width - btnW) / 2);
    end

    if self.stage == "done" then
        self.finishButton:setTitle(getText("IGUI_TCA_Finish"));
    else
        self.finishButton:setTitle(getText("IGUI_TCA_Stop"));
    end
end

function TCA_AutopsyUI:getTremorAmplitude()
    local chr = self.character;
    local amp = TCA_AutopsyUI.TREMOR_BASE - chr:getPerkLevel(Perks.Doctor) * TCA_AutopsyUI.TREMOR_PER_LEVEL;
    local moodles = chr:getMoodles();
    amp = amp + moodles:getMoodleLevel(MoodleType.PANIC) * 2.5;
    amp = amp + moodles:getMoodleLevel(MoodleType.DRUNK) * 2.5;
    amp = amp + moodles:getMoodleLevel(MoodleType.TIRED) * 1.0;
    amp = amp + moodles:getMoodleLevel(MoodleType.PAIN) * 1.2;
    amp = amp + moodles:getMoodleLevel(MoodleType.ENDURANCE) * 1.0;
    local desc = chr:getDescriptor();
    if desc and (desc:isCharacterProfession(CharacterProfession.DOCTOR) or desc:isCharacterProfession(CharacterProfession.NURSE)) then
        amp = amp - 2;
    end
    if amp < TCA_AutopsyUI.TREMOR_MIN then
        amp = TCA_AutopsyUI.TREMOR_MIN;
    end
    return amp;
end

function TCA_AutopsyUI:getTremorLabel(amp)
    if amp < 5 then
        return getText("IGUI_TCA_TremorLow");
    elseif amp < 10 then
        return getText("IGUI_TCA_TremorMedium");
    end
    return getText("IGUI_TCA_TremorHigh");
end

function TCA_AutopsyUI:updateBlade()
    local now = getTimestampMs();
    local dt = now - self.lastTime;
    if dt < 1 then
        dt = 1;
    end
    self.lastTime = now;
    self.dt = dt;

    local mx = self:getMouseX();
    local my = self:getMouseY();
    self.mouseDX = 0;
    self.mouseDY = 0;
    if self.lastMouseX then
        self.mouseDX = mx - self.lastMouseX;
        self.mouseDY = my - self.lastMouseY;
    end
    self.speed = math.sqrt(self.mouseDX * self.mouseDX + self.mouseDY * self.mouseDY) / dt;
    self.lastMouseX = mx;
    self.lastMouseY = my;

    local t = now / 1000;
    local amp = self:getTremorAmplitude() * (1 + math.min(self.speed, 2) * 0.5);
    local p = self.phase;
    self.bladeX = mx + amp * (0.5 * math.sin(t * 1.3 + p[1]) + 0.3 * math.sin(t * 3.7 + p[2]) + 0.2 * math.sin(t * 9.1 + p[3]));
    self.bladeY = my + amp * (0.5 * math.sin(t * 1.7 + p[4]) + 0.3 * math.sin(t * 4.1 + p[5]) + 0.2 * math.sin(t * 8.3 + p[6]));
end

function TCA_AutopsyUI:getSegmentScreen(index)
    local seg = self.segments[index];
    local ax, ay = self:toScreen(seg.ax, seg.ay);
    local bx, by = self:toScreen(seg.bx, seg.by);
    return ax, ay, bx, by;
end

function TCA_AutopsyUI:currentStartPoint()
    local ax, ay, bx, by = self:getSegmentScreen(self.segIndex);
    return ax + (bx - ax) * self.segProgress, ay + (by - ay) * self.segProgress;
end

function TCA_AutopsyUI:slip(reasonKey)
    self.cuts = self.cuts + 1;
    self.cutting = false;
    self.flashTime = getTimestampMs();
    HaloTextHelper.addBadText(self.character, getText(reasonKey));
    TCA_Client.requestCut(self.character);
end

function TCA_AutopsyUI:addPathPoint(screenX, screenY)
    local bx, by = self:toBody(screenX, screenY);
    local path = self.cutPaths[self.segIndex];
    local last = path[#path];
    if last and dist(last.x, last.y, bx, by) < TCA_AutopsyUI.PATH_STEP then
        return;
    end
    table.insert(path, { x = bx, y = by });
end

function TCA_AutopsyUI:updateCut()
    if not self.cutting or self.complete then
        return;
    end

    if self.speed > TCA_AutopsyUI.MAX_SPEED then
        self:slip("IGUI_TCA_TooFast");
        return;
    end

    local ax, ay, bx, by = self:getSegmentScreen(self.segIndex);
    local tProj, d = project(self.bladeX, self.bladeY, ax, ay, bx, by);

    if d > TCA_AutopsyUI.SLIP_DIST then
        self:slip("IGUI_TCA_Slip");
        return;
    end
    if d > TCA_AutopsyUI.WARN_DIST then
        self.warn = true;
        return;
    end

    if tProj > self.segProgress and tProj - self.segProgress <= TCA_AutopsyUI.MAX_STEP then
        self.segProgress = tProj;
        self.devSum = self.devSum + d;
        self.devCount = self.devCount + 1;
        self:addPathPoint(self.bladeX, self.bladeY);
    end

    if self.segProgress >= TCA_AutopsyUI.SEGMENT_DONE then
        self.cutting = false;
        if self.segIndex < #self.segments then
            self.segIndex = self.segIndex + 1;
            self.segProgress = 0;
        else
            self.segProgress = 1;
            self.complete = true;
            self:setStage("open");
        end
    end
end

function TCA_AutopsyUI:getRibScreen(index)
    local rib = TCA.Autopsy.RIBS[index];
    return self:toScreen(rib.x, rib.y);
end

function TCA_AutopsyUI:findRibAt(x, y)
    local best = nil;
    local bestDist = TCA_AutopsyUI.RIB_PICK_RADIUS;
    for i = 1, #TCA.Autopsy.RIBS do
        if not self.ribs[i] then
            local sx, sy = self:getRibScreen(i);
            local d = dist(x, y, sx, sy);
            if d <= bestDist then
                best = i;
                bestDist = d;
            end
        end
    end
    return best;
end

function TCA_AutopsyUI:getStrength()
    return self.character:getPerkLevel(Perks.Strength);
end

function TCA_AutopsyUI:getCutterHoldMs()
    local ms = TCA_AutopsyUI.CUTTER_HOLD_MS - self:getStrength() * TCA_AutopsyUI.CUTTER_HOLD_PER_STR;
    return math.max(ms, TCA_AutopsyUI.CUTTER_HOLD_MIN);
end

function TCA_AutopsyUI:getSawTravel()
    local travel = TCA_AutopsyUI.SAW_TRAVEL - self:getStrength() * TCA_AutopsyUI.SAW_TRAVEL_PER_STR;
    return math.max(travel, TCA_AutopsyUI.SAW_TRAVEL_MIN);
end

function TCA_AutopsyUI:ribSlip()
    local index = self.ribActive;
    self.cutting = false;
    self.ribActive = nil;
    if self.ribMode == "cutter" then
        self.ribWork[index] = 0;
        HaloTextHelper.addBadText(self.character, getText("IGUI_TCA_CutterSlip"));
        return;
    end
    if ZombRand(100) < TCA_AutopsyUI.SAW_CUT_CHANCE then
        self:slip("IGUI_TCA_SawSlipHurt");
    else
        HaloTextHelper.addBadText(self.character, getText("IGUI_TCA_SawSlip"));
    end
end

function TCA_AutopsyUI:finishRib(index)
    self.ribs[index] = true;
    self.ribWork[index] = 1;
    self.cutting = false;
    self.ribActive = nil;
    if TCA.Autopsy.countRibs(self.ribs) >= #TCA.Autopsy.RIBS then
        self:setStage("removing");
    end
end

function TCA_AutopsyUI:updateRibs()
    if not self.cutting or not self.ribActive or not self.ribMode then
        return;
    end
    local index = self.ribActive;
    local sx, sy = self:getRibScreen(index);

    if self.ribMode == "cutter" then
        local d = dist(self.bladeX, self.bladeY, sx, sy);
        if d > TCA_AutopsyUI.SLIP_DIST then
            self:ribSlip();
            return;
        end
        if d > TCA_AutopsyUI.WARN_DIST then
            self.warn = true;
            return;
        end
        self.ribWork[index] = self.ribWork[index] + self.dt / self:getCutterHoldMs();
    else
        local side = math.abs(self.bladeX - sx);
        local along = math.abs(self.bladeY - sy);
        if side > TCA_AutopsyUI.SLIP_DIST or along > TCA_AutopsyUI.SAW_STROKE_SLIP then
            self:ribSlip();
            return;
        end
        if side > TCA_AutopsyUI.WARN_DIST or along > TCA_AutopsyUI.SAW_STROKE_WARN then
            self.warn = true;
            return;
        end
        self.ribWork[index] = self.ribWork[index] + math.abs(self.mouseDY) / self:getSawTravel();
    end

    if self.ribWork[index] >= 1 then
        self:finishRib(index);
    end
end

function TCA_AutopsyUI:updateStage()
    self:updateBlade();
    self.warn = false;
    self:refreshTools(false);

    if self.stage == "incision" then
        self:updateCut();
    elseif self.stage == "opening" then
        if self:getStageFade(TCA_AutopsyUI.OPEN_FADE_MS) >= 1 then
            self:setStage("ribs");
        end
    elseif self.stage == "ribs" then
        self:updateRibs();
    elseif self.stage == "removing" then
        if self:getStageFade(TCA_AutopsyUI.REMOVE_FADE_MS) >= 1 then
            self:setStage("done");
        end
    end
end

function TCA_AutopsyUI:onMouseDown(x, y)
    if self.stage == "incision" then
        local sx, sy = self:currentStartPoint();
        if dist(self.bladeX, self.bladeY, sx, sy) <= TCA_AutopsyUI.START_RADIUS then
            self.cutting = true;
            self.lastMouseX = x;
            self.lastMouseY = y;
            self.lastTime = getTimestampMs();
        end
    elseif self.stage == "ribs" and self.ribMode then
        local index = self:findRibAt(self.bladeX, self.bladeY);
        if index then
            self.cutting = true;
            self.ribActive = index;
            if self.ribMode == "cutter" then
                self.ribWork[index] = 0;
            end
            self.lastMouseX = x;
            self.lastMouseY = y;
            self.lastTime = getTimestampMs();
        end
    end
    return true;
end

function TCA_AutopsyUI:releaseTool()
    if self.ribActive and self.ribMode == "cutter" and not self.ribs[self.ribActive] then
        self.ribWork[self.ribActive] = 0;
    end
    self.cutting = false;
    self.ribActive = nil;
end

function TCA_AutopsyUI:onMouseUp(x, y)
    self:releaseTool();
    return true;
end

function TCA_AutopsyUI:onMouseUpOutside(x, y)
    self:releaseTool();
    return true;
end

function TCA_AutopsyUI:drawBody()
    if self.model then
        TCA_BodyRenderer.drawShapes(self, true);
        return;
    end
    TCA_BodyRenderer.drawBody(self, false);
end

function TCA_AutopsyUI:drawLayer(tex, alpha)
    if not tex or alpha <= 0 then
        return;
    end
    local canvas = TCA_BodyRenderer.CANVAS;
    local x, y = self:toScreen(canvas.x1, canvas.y1);
    local w = (canvas.x2 - canvas.x1) * self.scale;
    local h = (canvas.y2 - canvas.y1) * self.scale;
    self:drawTextureScaled(tex, x, y, w, h, alpha, 1, 1, 1);
end

function TCA_AutopsyUI:drawLayers()
    local stage = self.stage;
    if stage == "opening" then
        self:drawLayer(self.layerOpened, self:getStageFade(TCA_AutopsyUI.OPEN_FADE_MS));
    elseif stage == "ribs" then
        self:drawLayer(self.layerOpened, 1);
    elseif stage == "removing" then
        self:drawLayer(self.layerOpened, 1);
        self:drawLayer(self.layerChest, self:getStageFade(TCA_AutopsyUI.REMOVE_FADE_MS));
    elseif stage == "done" then
        self:drawLayer(self.layerChest, 1);
    end
end

function TCA_AutopsyUI:drawIncisions(alpha)
    local dotSize = 3;
    for i, seg in ipairs(self.segments) do
        local ax, ay, bx, by = self:getSegmentScreen(i);

        local path = self.cutPaths[i];
        local prevX = ax;
        local prevY = ay;
        for _, pt in ipairs(path) do
            local sx, sy = self:toScreen(pt.x, pt.y);
            self:thickLineScreen(prevX, prevY, sx, sy, 3, CUT, alpha);
            prevX = sx;
            prevY = sy;
        end

        local fromT = -1;
        if i > self.segIndex then
            fromT = 0;
        elseif i == self.segIndex and not self.complete then
            fromT = self.segProgress;
        end
        if fromT >= 0 then
            local len = dist(ax, ay, bx, by);
            local count = math.max(math.floor(len / 10), 1);
            for k = 0, count do
                local t = k / count;
                if t >= fromT then
                    local x = ax + (bx - ax) * t;
                    local y = ay + (by - ay) * t;
                    self:drawRect(x - dotSize / 2, y - dotSize / 2, dotSize, dotSize, 0.85 * alpha, WHITE.r, WHITE.g, WHITE.b);
                end
            end
        end
    end

    if not self.complete then
        local sx, sy = self:currentStartPoint();
        local pulse = 0.5 + 0.5 * math.sin(getTimestampMs() / 200);
        local c = GREEN;
        if self.cutting then
            c = WHITE;
        end
        self:fillCircleScreen(sx, sy, 5 + pulse * 3, c, 0.6 * alpha);
    end
end

function TCA_AutopsyUI:drawRibs()
    local pulse = 0.5 + 0.5 * math.sin(getTimestampMs() / 200);
    local hover = nil;
    if not self.cutting and self.ribMode then
        hover = self:findRibAt(self.bladeX, self.bladeY);
    end
    for i = 1, #TCA.Autopsy.RIBS do
        local sx, sy = self:getRibScreen(i);
        if self.ribs[i] then
            self:thickLineScreen(sx, sy - 4, sx, sy + 4, 3, GAP, 0.9);
        else
            local c = WHITE;
            local haloA = 0.15;
            if i == hover or i == self.ribActive then
                c = GREEN;
                haloA = 0.35;
            end
            self:fillCircleScreen(sx, sy, 5 + pulse * 2, c, haloA);
            self:fillCircleScreen(sx, sy, 2, c, 0.85);
            local work = self.ribWork[i];
            if work > 0 then
                self:fillCircleScreen(sx, sy, 2 + 5 * work, RED, 0.7);
            end
        end
    end
end

function TCA_AutopsyUI:drawScalpel(c)
    self:thickLineScreen(self.bladeX, self.bladeY, self.bladeX + 10, self.bladeY - 10, 2, c, 1);
    self:thickLineScreen(self.bladeX + 10, self.bladeY - 10, self.bladeX + 24, self.bladeY - 24, 4, HANDLE, 1);
end

function TCA_AutopsyUI:drawCutter(c)
    local x = self.bladeX;
    local y = self.bladeY;
    local work = 0;
    if self.ribActive then
        work = self.ribWork[self.ribActive];
    end
    local gap = 5 * (1 - work);
    local pivotX = x + 7;
    local pivotY = y + 9;
    self:thickLineScreen(x - gap, y - 1, pivotX, pivotY, 3, c, 1);
    self:thickLineScreen(x + gap, y + 1, pivotX, pivotY, 3, c, 1);
    self:thickLineScreen(pivotX, pivotY, pivotX + 22 - gap, pivotY + 34, 4, CUTTER_HANDLE, 1);
    self:thickLineScreen(pivotX, pivotY, pivotX + 30 + gap, pivotY + 26, 4, CUTTER_HANDLE, 1);
end

function TCA_AutopsyUI:drawSaw(c)
    local x = self.bladeX;
    local y = self.bladeY;
    self:thickLineScreen(x, y - 16, x, y + 16, 4, c, 1);
    for k = -14, 14, 4 do
        self:thickLineScreen(x - 2, y + k, x - 4, y + k + 2, 1, STEEL, 1);
    end
    self:thickLineScreen(x + 1, y + 16, x + 1, y + 30, 8, HANDLE, 1);
end

function TCA_AutopsyUI:drawTool()
    local c = BLADE;
    if self.warn then
        c = RED;
    end
    if self.stage == "incision" then
        self:drawScalpel(c);
    elseif self.stage == "ribs" then
        if self.ribMode == "cutter" then
            self:drawCutter(c);
        elseif self.ribMode == "saw" then
            self:drawSaw(c);
        end
    end
end

function TCA_AutopsyUI:getProgress()
    if self.complete then
        return 1;
    end
    return TCA.Autopsy.getFraction(self.segIndex, self.segProgress);
end

function TCA_AutopsyUI:getAccuracy()
    if self.devCount == 0 then
        return 0;
    end
    local acc = 1 - (self.devSum / self.devCount) / TCA_AutopsyUI.WARN_DIST;
    if acc < 0 then
        acc = 0;
    end
    return acc;
end

function TCA_AutopsyUI:getTitleText()
    if self.stage == "incision" or self.stage == "open" then
        return getText("IGUI_TCA_AutopsyTitle");
    end
    return getText("IGUI_TCA_AutopsyTitleChest");
end

function TCA_AutopsyUI:getInstructionText()
    local stage = self.stage;
    if stage == "incision" then
        return getText("IGUI_TCA_Instructions");
    elseif stage == "open" then
        return getText("IGUI_TCA_InstrOpen");
    elseif stage == "opening" then
        return getText("IGUI_TCA_InstrOpening");
    elseif stage == "ribs" then
        if self.ribMode == "cutter" then
            return getText("IGUI_TCA_InstrRibsCutter");
        elseif self.ribMode == "saw" then
            return getText("IGUI_TCA_InstrRibsSaw");
        end
        return getText("Tooltip_TCA_NeedRibTool");
    elseif stage == "removing" then
        return getText("IGUI_TCA_InstrRemoving");
    end
    return getText("IGUI_TCA_InstrDone");
end

function TCA_AutopsyUI:getMissingToolText()
    if self.stage == "open" and not self.hasForceps then
        return getText("Tooltip_TCA_NeedForceps");
    elseif self.stage == "ribs" and not self.ribMode then
        return getText("Tooltip_TCA_NeedRibTool");
    end
    return nil;
end

function TCA_AutopsyUI:drawInstructions()
    local warning = self:getMissingToolText();
    if not warning then
        self:drawTextCentre(self:getInstructionText(), self.width / 2, self.instructionsY, 0.8, 0.8, 0.8, 1, UIFont.Small);
        return;
    end
    local tm = getTextManager();
    local textW = tm:MeasureStringX(UIFont.Small, warning);
    local textH = tm:getFontHeight(UIFont.Small);
    local pulse = 0.5 + 0.5 * math.sin(getTimestampMs() / 300);
    local boxW = textW + 16;
    local boxX = (self.width - boxW) / 2;
    local boxY = self.instructionsY - 2;
    self:drawRect(boxX, boxY, boxW, textH + 4, 0.6 + 0.25 * pulse, WARN_BG.r, WARN_BG.g, WARN_BG.b);
    self:drawRectBorder(boxX, boxY, boxW, textH + 4, 0.8, WARN_TEXT.r, WARN_TEXT.g, WARN_TEXT.b);
    self:drawTextCentre(warning, self.width / 2, self.instructionsY, WARN_TEXT.r, WARN_TEXT.g, WARN_TEXT.b, 1, UIFont.Small);
end

function TCA_AutopsyUI:drawMissingToolTooltip()
    local warning = self:getMissingToolText();
    if not warning or not self:isMouseOverView() then
        return;
    end
    local tm = getTextManager();
    local textW = tm:MeasureStringX(UIFont.Small, warning);
    local textH = tm:getFontHeight(UIFont.Small);
    local boxW = textW + 12;
    local boxH = textH + 8;
    local x = self:getMouseX() + 16;
    local y = self:getMouseY() + 18;
    if x + boxW > self.width - 4 then
        x = self.width - 4 - boxW;
    end
    if y + boxH > self.height - 4 then
        y = self:getMouseY() - boxH - 6;
    end
    self:drawRect(x, y, boxW, boxH, 0.9, 0.05, 0.05, 0.06);
    self:drawRectBorder(x, y, boxW, boxH, 1, WARN_TEXT.r, WARN_TEXT.g, WARN_TEXT.b);
    self:drawText(warning, x + 6, y + 4, WARN_TEXT.r, WARN_TEXT.g, WARN_TEXT.b, 1, UIFont.Small);
end

function TCA_AutopsyUI:drawInfo()
    local infoY = self.height - 80;
    local smallH = getTextManager():getFontHeight(UIFont.Small);
    if self.stage == "incision" or self.stage == "open" or self.stage == "opening" then
        local progress = math.floor(self:getProgress() * 100);
        local accuracy = math.floor(self:getAccuracy() * 100);
        self:drawText(getText("IGUI_TCA_Progress", progress .. "%"), 20, infoY, 1, 1, 1, 1, UIFont.Small);
        self:drawText(getText("IGUI_TCA_Accuracy", accuracy .. "%"), 20, infoY + smallH, 1, 1, 1, 1, UIFont.Small);
    else
        local done = TCA.Autopsy.countRibs(self.ribs);
        self:drawText(getText("IGUI_TCA_Ribs", done, #TCA.Autopsy.RIBS), 20, infoY, 1, 1, 1, 1, UIFont.Small);
        if self.ribTool then
            self:drawText(getText("IGUI_TCA_Tool", self.ribTool:getDisplayName()), 20, infoY + smallH, 0.8, 0.8, 0.8, 1, UIFont.Small);
        end
    end
    self:drawTextRight(getText("IGUI_TCA_Cuts", self.cuts), self.width - 20, infoY, 1, 0.6, 0.6, 1, UIFont.Small);
    self:drawTextRight(self:getTremorLabel(self:getTremorAmplitude()), self.width - 20, infoY + smallH, 0.8, 0.8, 1, 1, UIFont.Small);
end

function TCA_AutopsyUI:prerender()
    ISPanel.prerender(self);
    self:updateStage();

    self:drawTextCentre(self:getTitleText(), self.width / 2, self.titleY, 1, 1, 1, 1, UIFont.Medium);
    self:drawInstructions();

    self:setStencilRect(self.viewX, self.viewY, self.viewW, self.viewH);
    self:drawBody();
    self:clearStencilRect();

    self:drawInfo();
end

function TCA_AutopsyUI:isMouseOverView()
    local mx = self:getMouseX();
    local my = self:getMouseY();
    return mx >= self.viewX and my >= self.viewY and mx < self.viewX + self.viewW and my < self.viewY + self.viewH;
end

function TCA_AutopsyUI:isToolShown()
    return self.stage == "incision" or (self.stage == "ribs" and self.ribMode ~= nil);
end

function TCA_AutopsyUI:wantsHiddenCursor()
    if not TCA_AutopsyUI.HIDE_CURSOR or not self:getIsVisible() or not self:isToolShown() then
        return false;
    end
    return self.cutting or self:isMouseOverView();
end

function TCA_AutopsyUI.onTickHideCursor()
    local ui = TCA_AutopsyUI.instance;
    if ui and ui:wantsHiddenCursor() then
        Mouse.setCursorVisible(false);
    end
end

Events.OnTick.Add(TCA_AutopsyUI.onTickHideCursor);
Events.OnTickEvenPaused.Add(TCA_AutopsyUI.onTickHideCursor);

function TCA_AutopsyUI:isMouseInside()
    local mx = self:getMouseX();
    local my = self:getMouseY();
    return mx >= 0 and my >= 0 and mx < self.width and my < self.height;
end

function TCA_AutopsyUI:render()
    ISPanel.render(self);
    self:setStencilRect(self.viewX, self.viewY, self.viewW, self.viewH);
    self:drawLayers();
    if self.stage == "incision" or self.stage == "open" then
        self:drawIncisions(1);
    elseif self.stage == "opening" then
        self:drawIncisions(1 - self:getStageFade(TCA_AutopsyUI.OPEN_FADE_MS));
    elseif self.stage == "ribs" then
        self:drawRibs();
    end
    self:clearStencilRect();
    self:drawRectBorder(self.viewX, self.viewY, self.viewW, self.viewH, 1, 0.3, 0.3, 0.32);

    if self:isMouseInside() or self.cutting then
        self:drawTool();
    end
    local elapsed = getTimestampMs() - self.flashTime;
    if elapsed < 300 then
        self:drawRect(0, 0, self.width, self.height, 0.35 * (1 - elapsed / 300), 0.8, 0, 0);
    end
    self:drawMissingToolTooltip();
end

function TCA_AutopsyUI:collectResult()
    local A = TCA.Autopsy;
    local result = {};
    result.segIndex = self.segIndex;
    result.segProgress = self.segProgress;
    if self.complete then
        result.segIndex = #self.segments + 1;
        result.segProgress = 0;
    end
    result.accuracy = self:getAccuracy();
    result.accSamples = self.devCount;
    result.paths = A.encodePaths(self.cutPaths);
    result.opened = self.opened and self.startStep < A.STEP_OPENED;
    result.ribs = A.encodeRibs(self.ribs);
    local newRibs = A.countRibs(self.ribs) > self.startRibCount;
    result.advanced = self:getProgress() > self.startFraction + 0.0001 or result.opened or newRibs;
    return result;
end

function TCA_AutopsyUI:closeSilently()
    self:setVisible(false);
    self:removeFromUIManager();
    if TCA_AutopsyUI.instance == self then
        TCA_AutopsyUI.instance = nil;
    end
end

function TCA_AutopsyUI.open(character, tableObject)
    if TCA_AutopsyUI.instance then
        TCA_AutopsyUI.instance:closeSilently();
    end
    local w = TCA_AutopsyUI.WIDTH;
    local h = TCA_AutopsyUI.HEIGHT;
    local x = (getCore():getScreenWidth() - w) / 2;
    local y = (getCore():getScreenHeight() - h) / 2;
    local ui = TCA_AutopsyUI:new(x, y, w, h, character, tableObject);
    ui:initialise();
    ui:instantiate();
    ui:addToUIManager();
    TCA_AutopsyUI.instance = ui;
    return ui;
end

function TCA_AutopsyUI:new(x, y, width, height, character, tableObject)
    local o = ISPanel.new(self, x, y, width, height);
    o.character = character;
    o.tableObject = tableObject;
    o.backgroundColor = { r = 0.08, g = 0.08, b = 0.09, a = 0.95 };
    o.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 };
    o.moveWithMouse = false;
    return o;
end
