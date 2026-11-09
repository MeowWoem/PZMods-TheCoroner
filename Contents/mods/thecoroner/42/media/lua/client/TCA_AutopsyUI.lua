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

TCA_AutopsyUI.OPEN_HALF_WIDTH = 50;
TCA_AutopsyUI.OPEN_Y1 = 100;
TCA_AutopsyUI.OPEN_Y2 = 222;
TCA_AutopsyUI.OPEN_TOP_CENTER = 107.5;
TCA_AutopsyUI.OPEN_TOP_CORNER = 96;
TCA_AutopsyUI.OPEN_CORNER_X = 37.5;
TCA_AutopsyUI.OPEN_BOTTOM = 225;
TCA_AutopsyUI.GRAB_RADIUS = 12;
TCA_AutopsyUI.GRIP_DIST = 16;
TCA_AutopsyUI.SIDE_DECIDE = 4;
TCA_AutopsyUI.TEAR_SPEED = 0.25;
TCA_AutopsyUI.TEAR_LOSS = 0.12;
TCA_AutopsyUI.FOLD_WIDTH = 4;
TCA_AutopsyUI.FOLD_STEP = 4;

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
local FOLD_SKIN = { r = 0.74, g = 0.7, b = 0.62 };
local FOLD_SHADOW = { r = 0.12, g = 0.03, b = 0.03 };
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
    if not (len >= 0.01) or len > 100000 then
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
    local openState = { left = 0, right = 0, tears = 0 };
    local body = TCA.findBodyOnTable(self.tableObject);
    if body then
        state = A.getState(body);
        step = A.getStep(body);
        ribsStr = body:getModData()["TCA_A_ribs"];
        openState = A.getOpenState(body);
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
    self.openL = openState.left;
    self.openR = openState.right;
    self.tears = openState.tears;
    if step >= A.STEP_OPENED then
        self.openL = 1;
        self.openR = 1;
    end
    self.startOpenL = self.openL;
    self.startOpenR = self.openR;
    self.startTears = self.tears;
    self.pullSide = nil;
    self.pullStartMouseX = 0;
    self.pullSpeed = 0;
    self.ribs = A.decodeRibs(ribsStr);
    self.startRibCount = A.countRibs(self.ribs);
    self.ribWork = {};
    for i = 1, #A.RIBS do
        self.ribWork[i] = 0;
    end
    self.ribActive = nil;
    self.ribTool = nil;
    self.ribMode = nil;
    self.ribDef = nil;
    self.toolCheckTime = 0;
    self.hasForceps = false;

    self.layerOpened = getTexture(TCA_AutopsyUI.LAYER_OPENED);
    self.layerChest = getTexture(TCA_AutopsyUI.LAYER_CHEST);
    self:initOrgans(body);

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
        if A.countRibs(self.ribs) >= #A.RIBS then
            self.stage = "plastron";
        end
    else
        self.stage = self:getStageAfterChest();
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

    if TCA_Client.isDebug() then
        local dbgW = 110;
        local dbgH = 20;
        local dbgY = self.height - dbgH - 14;
        self.debugPrevButton = ISButton:new(10, dbgY, dbgW, dbgH, getText("IGUI_TCA_DebugPrev"), self, TCA_AutopsyUI.onDebugPrev);
        self.debugPrevButton:initialise();
        self.debugPrevButton:instantiate();
        self:addChild(self.debugPrevButton);
        self.debugNextButton = ISButton:new(self.width - dbgW - 10, dbgY, dbgW, dbgH, getText("IGUI_TCA_DebugNext"), self, TCA_AutopsyUI.onDebugNext);
        self.debugNextButton:initialise();
        self.debugNextButton:instantiate();
        self:addChild(self.debugNextButton);
    end

    self:createBodyModel();
    self:refreshTools(true);
end

function TCA_AutopsyUI:getDebugPosition()
    local stage = self.stage;
    if stage == "incision" then
        return 0;
    elseif stage == "open" then
        return 1;
    elseif stage == "ribs" then
        return 2;
    elseif stage == "plastron" then
        return 3;
    end
    return 4 + self.organsDone;
end

function TCA_AutopsyUI:onDebugPrev()
    self:debugGoTo(self:getDebugPosition() - 1);
end

function TCA_AutopsyUI:onDebugNext()
    self:debugGoTo(self:getDebugPosition() + 1);
end

function TCA_AutopsyUI:debugGoTo(pos)
    local A = TCA.Autopsy;
    pos = math.max(0, math.min(pos, A.getDebugLast()));
    TCA_Client.debugSetStep(self.character, self.tableObject, pos);

    self.complete = pos >= 1;
    if self.complete then
        self.segIndex = #self.segments;
        self.segProgress = 1;
        self.cutPaths = A.decodePaths(A.encodePaths(A.getDebugStraightPaths()));
        self.devCount = 1;
        self.devSum = 0;
    else
        self.segIndex = 1;
        self.segProgress = 0;
        self.cutPaths = A.decodePaths("");
        self.devCount = 0;
        self.devSum = 0;
    end
    self.startFraction = A.getFraction(self.segIndex, self.segProgress);
    if self.complete then
        self.startFraction = 1;
    end

    local opened = 0;
    if pos >= 2 then
        opened = 1;
    end
    self.openL = opened;
    self.openR = opened;
    self.tears = 0;
    self.startOpenL = opened;
    self.startOpenR = opened;
    self.startTears = 0;

    for i = 1, #A.RIBS do
        self.ribs[i] = pos >= 3;
        self.ribWork[i] = 0;
    end
    self.startRibCount = A.countRibs(self.ribs);
    self.plastronRemoved = pos >= 4;
    self.startPlastron = self.plastronRemoved;

    self.organsDone = math.max(pos - 4, 0);
    self.organDamage = 0;
    self.startOrgansDone = self.organsDone;
    self.startOrganDamage = 0;
    self.organFly = nil;
    self:resetCurrentOrgan();

    local stage = "incision";
    if pos == 1 then
        stage = "open";
    elseif pos == 2 then
        stage = "ribs";
    elseif pos == 3 then
        stage = "plastron";
    elseif pos >= 4 then
        stage = self:getStageAfterChest();
    end
    self:setStage(stage);
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

function TCA_AutopsyUI:setStage(stage)
    self.stage = stage;
    self.stageTime = getTimestampMs();
    self.cutting = false;
    self.ribActive = nil;
    self.pullSide = nil;
    self.attachActive = nil;
    self.organDrag = nil;
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
        self.ribTool, self.ribMode, self.ribDef = TCA.Autopsy.findRibTool(self.character);
    end
    if self.stage == "open" and not self.cutting then
        self.forcepsTool = TCA.Autopsy.findForceps(self.character);
        self.hasForceps = self.forcepsTool ~= nil;
    end
    self:refreshOrganTools();

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

function TCA_AutopsyUI:getEdgeScreenX(side)
    local half = TCA_AutopsyUI.OPEN_HALF_WIDTH;
    if side == "left" then
        local x = self:toScreen(-half * self.openL, 0);
        return x;
    end
    local x = self:toScreen(half * self.openR, 0);
    return x;
end

function TCA_AutopsyUI:isSideOpen(side)
    if side == "left" then
        return self.openL >= TCA.Autopsy.OPEN_DONE;
    end
    return self.openR >= TCA.Autopsy.OPEN_DONE;
end

function TCA_AutopsyUI:findOpenEdgeAt(x, y)
    local _, by = self:toBody(x, y);
    if by < TCA_AutopsyUI.OPEN_Y1 or by > TCA_AutopsyUI.OPEN_Y2 then
        return nil;
    end
    local leftOk = not self:isSideOpen("left") and math.abs(x - self:getEdgeScreenX("left")) <= TCA_AutopsyUI.GRAB_RADIUS;
    local rightOk = not self:isSideOpen("right") and math.abs(x - self:getEdgeScreenX("right")) <= TCA_AutopsyUI.GRAB_RADIUS;
    if leftOk and rightOk then
        if math.abs(self:getEdgeScreenX("left") - self:getEdgeScreenX("right")) < 1 then
            return "pending";
        end
        if math.abs(x - self:getEdgeScreenX("left")) <= math.abs(x - self:getEdgeScreenX("right")) then
            return "left";
        end
        return "right";
    end
    if leftOk then
        return "left";
    end
    if rightOk then
        return "right";
    end
    return nil;
end

function TCA_AutopsyUI:releaseFlap()
    self.cutting = false;
    self.pullSide = nil;
end

function TCA_AutopsyUI:loseGrip()
    self:releaseFlap();
    HaloTextHelper.addBadText(self.character, getText("IGUI_TCA_GripLost"));
end

function TCA_AutopsyUI:tearSkin()
    local loss = TCA_AutopsyUI.TEAR_LOSS;
    if self.pullSide == "left" then
        self.openL = math.max(self.openL - loss, 0);
    else
        self.openR = math.max(self.openR - loss, 0);
    end
    self.tears = self.tears + 1;
    self:releaseFlap();
    HaloTextHelper.addBadText(self.character, getText("IGUI_TCA_SkinTear"));
end

function TCA_AutopsyUI:updateOpen()
    if not self.cutting or not self.pullSide then
        self.pullSpeed = 0;
        return;
    end
    local _, by = self:toBody(self.bladeX, self.bladeY);
    if by < TCA_AutopsyUI.OPEN_Y1 - 8 or by > TCA_AutopsyUI.OPEN_Y2 + 8 then
        self:loseGrip();
        return;
    end
    if self.pullSide == "pending" then
        local mx = self:getMouseX();
        if mx < self.pullStartMouseX - TCA_AutopsyUI.SIDE_DECIDE then
            self.pullSide = "left";
        elseif mx > self.pullStartMouseX + TCA_AutopsyUI.SIDE_DECIDE then
            self.pullSide = "right";
        else
            return;
        end
    end

    local side = self.pullSide;
    local outwardDX = self.mouseDX;
    if side == "left" then
        outwardDX = -self.mouseDX;
    end
    self.pullSpeed = self.pullSpeed * 0.7 + (math.max(outwardDX, 0) / self.dt) * 0.3;
    if self.pullSpeed > TCA_AutopsyUI.TEAR_SPEED then
        self:tearSkin();
        return;
    end
    if self.pullSpeed > TCA_AutopsyUI.TEAR_SPEED * 0.75 then
        self.warn = true;
    end

    local edgeX = self:getEdgeScreenX(side);
    local outward = self.bladeX - edgeX;
    if side == "left" then
        outward = edgeX - self.bladeX;
    end
    if outward < -TCA_AutopsyUI.GRIP_DIST then
        self:loseGrip();
        return;
    end

    local bx = self:toBody(self.bladeX, self.bladeY);
    local p = clamp01(math.abs(bx) / TCA_AutopsyUI.OPEN_HALF_WIDTH);
    if side == "left" and bx < 0 and p > self.openL then
        self.openL = p;
    elseif side == "right" and bx > 0 and p > self.openR then
        self.openR = p;
    end

    if self:isSideOpen(side) then
        if side == "left" then
            self.openL = 1;
        else
            self.openR = 1;
        end
        self:releaseFlap();
        if self:isSideOpen("left") and self:isSideOpen("right") then
            self:setStage("ribs");
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

function TCA_AutopsyUI:getRibParam(key, default)
    if self.ribDef and self.ribDef[key] ~= nil then
        return self.ribDef[key];
    end
    return default;
end

function TCA_AutopsyUI:getCutterHoldMs()
    local ms = TCA_AutopsyUI.CUTTER_HOLD_MS - self:getStrength() * TCA_AutopsyUI.CUTTER_HOLD_PER_STR;
    return math.max(ms, TCA_AutopsyUI.CUTTER_HOLD_MIN) * self:getRibParam("holdMul", 1);
end

function TCA_AutopsyUI:getSawTravel()
    local travel = TCA_AutopsyUI.SAW_TRAVEL - self:getStrength() * TCA_AutopsyUI.SAW_TRAVEL_PER_STR;
    return math.max(travel, TCA_AutopsyUI.SAW_TRAVEL_MIN) * self:getRibParam("travelMul", 1);
end

function TCA_AutopsyUI:getRibSlipDist()
    return TCA_AutopsyUI.SLIP_DIST * self:getRibParam("slipMul", 1);
end

function TCA_AutopsyUI:getRibWarnDist()
    return TCA_AutopsyUI.WARN_DIST * self:getRibParam("slipMul", 1);
end

function TCA_AutopsyUI:isOscillating()
    return self.ribDef ~= nil and self.ribDef.id == "oscillating";
end

function TCA_AutopsyUI:ribSlip()
    local index = self.ribActive;
    self.cutting = false;
    self.ribActive = nil;
    if self.ribMode == "cutter" then
        self.ribWork[index] = 0;
        if self:isOscillating() then
            HaloTextHelper.addBadText(self.character, getText("IGUI_TCA_OscillatingSlip"));
        else
            HaloTextHelper.addBadText(self.character, getText("IGUI_TCA_CutterSlip"));
        end
        return;
    end
    if ZombRand(100) < self:getRibParam("cutChance", TCA_AutopsyUI.SAW_CUT_CHANCE) then
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
    if self.ribDef and self.ribDef.needsCharge then
        self:commitProgress();
        self:refreshTools(true);
    end
    if TCA.Autopsy.countRibs(self.ribs) >= #TCA.Autopsy.RIBS then
        self:setStage("plastron");
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
        if d > self:getRibSlipDist() then
            self:ribSlip();
            return;
        end
        if d > self:getRibWarnDist() then
            self.warn = true;
            return;
        end
        self.ribWork[index] = self.ribWork[index] + self.dt / self:getCutterHoldMs();
    else
        local side = math.abs(self.bladeX - sx);
        local along = math.abs(self.bladeY - sy);
        local slipMul = self:getRibParam("slipMul", 1);
        if side > self:getRibSlipDist() or along > TCA_AutopsyUI.SAW_STROKE_SLIP * slipMul then
            self:ribSlip();
            return;
        end
        if side > self:getRibWarnDist() or along > TCA_AutopsyUI.SAW_STROKE_WARN * slipMul then
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
    elseif self.stage == "open" then
        self:updateOpen();
    elseif self.stage == "ribs" then
        self:updateRibs();
    elseif self.stage == "plastron" then
        self:updatePlastron();
    elseif self.stage == "organs" then
        self:updateOrgans();
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
    elseif self.stage == "open" and self.hasForceps then
        local side = self:findOpenEdgeAt(self.bladeX, self.bladeY);
        if side then
            self.cutting = true;
            self.pullSide = side;
            self.pullStartMouseX = x;
            self.pullSpeed = 0;
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
    elseif self.stage == "plastron" then
        self:plastronMouseDown(x, y);
    elseif self.stage == "organs" then
        self:organMouseDown(x, y);
    end
    return true;
end

function TCA_AutopsyUI:releaseTool()
    if self.ribActive and self.ribMode == "cutter" and not self.ribs[self.ribActive] then
        self.ribWork[self.ribActive] = 0;
    end
    if self.stage == "organs" or self.stage == "plastron" then
        self:organRelease();
    end
    self.cutting = false;
    self.ribActive = nil;
    self.pullSide = nil;
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
    if stage == "ribs" then
        self:drawLayer(self.layerOpened, 1);
    elseif stage == "plastron" then
        self:drawPlastronLayers();
    elseif stage == "organs" or stage == "done" then
        self:drawOrganLayers();
    end
end

function TCA_AutopsyUI:getOpenTopY(x)
    local ax = math.min(math.abs(x), TCA_AutopsyUI.OPEN_CORNER_X);
    local center = TCA_AutopsyUI.OPEN_TOP_CENTER;
    return center - (center - TCA_AutopsyUI.OPEN_TOP_CORNER) * ax / TCA_AutopsyUI.OPEN_CORNER_X;
end

function TCA_AutopsyUI:getFoldWobble(y)
    return math.sin(y * 0.37) * 0.6 + math.sin(y * 0.11 + 1.3) * 0.5;
end

function TCA_AutopsyUI:drawFold(side, progress)
    if progress <= 0 or progress >= TCA.Autopsy.OPEN_DONE then
        return;
    end
    local half = TCA_AutopsyUI.OPEN_HALF_WIDTH;
    local bodyX = half * progress;
    local dir = 1;
    if side == "left" then
        bodyX = -bodyX;
        dir = -1;
    end
    local fade = 1;
    if math.abs(bodyX) > TCA_AutopsyUI.OPEN_CORNER_X then
        fade = clamp01(1 - (math.abs(bodyX) - TCA_AutopsyUI.OPEN_CORNER_X) / (half - TCA_AutopsyUI.OPEN_CORNER_X));
    end
    local top = self:getOpenTopY(bodyX);
    local bottom = TCA_AutopsyUI.OPEN_BOTTOM;
    local stepY = TCA_AutopsyUI.FOLD_STEP;
    local w = TCA_AutopsyUI.FOLD_WIDTH;
    local y = top;
    while y < bottom do
        local y2 = math.min(y + stepY, bottom);
        local xa, sya = self:toScreen(bodyX + self:getFoldWobble(y), y);
        local xb, syb = self:toScreen(bodyX + self:getFoldWobble(y2), y2);
        for k = 1, 3 do
            local off = -dir * (w * 0.5 + k * 2);
            self:thickLineScreen(xa + off, sya, xb + off, syb, 2, FOLD_SHADOW, 0.32 * fade / k);
        end
        self:thickLineScreen(xa + dir * w * 0.5, sya, xb + dir * w * 0.5, syb, w, FOLD_SKIN, 0.95 * fade);
        self:thickLineScreen(xa + dir * (w - 0.5), sya, xb + dir * (w - 0.5), syb, 1, FOLD_SHADOW, 0.35 * fade);
        y = y2;
    end
end

function TCA_AutopsyUI:drawOpening()
    local half = TCA_AutopsyUI.OPEN_HALF_WIDTH;
    local x1 = self:toScreen(-half * self.openL, 0);
    local x2 = self:toScreen(half * self.openR, 0);
    if x2 - x1 >= 1 then
        self:clearStencilRect();
        self:setStencilRect(x1, self.viewY, x2 - x1, self.viewH);
        self:drawLayer(self.layerOpened, 1);
        self:clearStencilRect();
        self:setStencilRect(self.viewX, self.viewY, self.viewW, self.viewH);
    end
    self:drawFold("left", self.openL);
    self:drawFold("right", self.openR);
    if not self.cutting and self.hasForceps and self:findOpenEdgeAt(self.bladeX, self.bladeY) then
        self:fillCircleScreen(self.bladeX, self.bladeY, 7, GREEN, 0.35);
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

function TCA_AutopsyUI:drawOscillatingSaw(c)
    local x = self.bladeX;
    local y = self.bladeY;
    local shake = 0;
    if self.cutting and self.ribActive then
        shake = math.sin(getTimestampMs() / 12) * 1.2;
    end
    self:drawRect(x - 5 + shake, y - 1.5, 10, 3, 1, c.r, c.g, c.b);
    self:thickLineScreen(x + 0.5, y + 1, x + 4, y + 10, 2, STEEL, 1);
    self:thickLineScreen(x + 4, y + 10, x + 20, y + 38, 9, CUTTER_HANDLE, 1);
    self:thickLineScreen(x + 14, y + 27, x + 17, y + 32, 2, GREEN, 1);
end

function TCA_AutopsyUI:drawForceps(c)
    local x = self.bladeX;
    local y = self.bladeY;
    local gap = 3;
    if self.cutting then
        gap = 0.5;
    end
    self:thickLineScreen(x - gap, y, x + 14, y - 26, 2, c, 1);
    self:thickLineScreen(x + gap, y + gap, x + 20, y - 22, 2, c, 1);
    self:thickLineScreen(x + 14, y - 26, x + 20, y - 22, 3, STEEL, 1);
end

function TCA_AutopsyUI:drawTool()
    local c = BLADE;
    if self.warn then
        c = RED;
    end
    if self.stage == "incision" then
        self:drawScalpel(c);
    elseif self.stage == "open" then
        if self.hasForceps then
            self:drawForceps(c);
        end
    elseif self.stage == "ribs" then
        if self:isOscillating() then
            self:drawOscillatingSaw(c);
        elseif self.ribMode == "cutter" then
            self:drawCutter(c);
        elseif self.ribMode == "saw" then
            self:drawSaw(c);
        end
    elseif self.stage == "organs" then
        if self.hasScalpel and self:needsScalpelForOrgans() then
            self:drawScalpel(c);
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
    if self.stage == "incision" then
        return getText("IGUI_TCA_AutopsyTitle");
    end
    if self.stage == "organs" or self.stage == "done" then
        return getText("IGUI_TCA_AutopsyTitleOrgans");
    end
    return getText("IGUI_TCA_AutopsyTitleChest");
end

function TCA_AutopsyUI:getInstructionText()
    local stage = self.stage;
    if stage == "incision" then
        return getText("IGUI_TCA_Instructions");
    elseif stage == "open" then
        return getText("IGUI_TCA_InstrOpen");
    elseif stage == "ribs" then
        if self:isOscillating() then
            return getText("IGUI_TCA_InstrRibsOscillating");
        elseif self.ribMode == "cutter" then
            return getText("IGUI_TCA_InstrRibsCutter");
        elseif self.ribMode == "saw" then
            return getText("IGUI_TCA_InstrRibsSaw");
        end
        return getText("Tooltip_TCA_NeedRibTool");
    elseif stage == "plastron" then
        return getText("IGUI_TCA_InstrPlastron");
    elseif stage == "organs" then
        return self:getOrganInstructionText();
    end
    return getText("IGUI_TCA_InstrDone");
end

function TCA_AutopsyUI:getMissingToolText()
    if self.stage == "open" and not self.hasForceps then
        return getText("Tooltip_TCA_NeedForceps");
    elseif self.stage == "ribs" and not self.ribMode then
        return getText("Tooltip_TCA_NeedRibTool");
    elseif self:needsScalpelForOrgans() and not self.hasScalpel then
        return getText("Tooltip_TCA_NeedScalpel");
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
    if self.stage == "open" then
        local opened = math.floor((self.openL + self.openR) / 2 * 100);
        self:drawText(getText("IGUI_TCA_SkinOpened", opened .. "%"), 20, infoY, 1, 1, 1, 1, UIFont.Small);
        self:drawText(getText("IGUI_TCA_Tears", self.tears), 20, infoY + smallH, 1, 1, 1, 1, UIFont.Small);
    elseif self.stage == "organs" or self.stage == "done" then
        self:drawOrganInfo(infoY, smallH);
    elseif self.stage == "incision" then
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
    if self.stage == "incision" then
        return true;
    end
    if self.stage == "open" then
        return self.hasForceps;
    end
    if self.stage == "organs" then
        return self.hasScalpel and self:needsScalpelForOrgans();
    end
    return self.stage == "ribs" and self.ribMode ~= nil;
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
    if self.stage == "incision" then
        self:drawIncisions(1);
    elseif self.stage == "open" then
        self:drawIncisions(1);
        self:drawOpening();
    elseif self.stage == "ribs" then
        self:drawRibs();
    elseif self.stage == "plastron" then
        self:drawPlastron();
    elseif self.stage == "organs" then
        self:drawOrgans();
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
    self:drawOrganTooltip();
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
    result.openL = self.openL;
    result.openR = self.openR;
    result.tears = self.tears;
    result.ribs = A.encodeRibs(self.ribs);
    result.organs = self.organsDone;
    result.organDamage = self.organDamage;
    result.plastron = self.plastronRemoved and not self.startPlastron;
    result.attach = self:getAttachString();
    local organsChanged = result.plastron or self.organsDone > self.startOrgansDone or self.organDamage > self.startOrganDamage or result.attach ~= self.startAttach;
    local newRibs = A.countRibs(self.ribs) > self.startRibCount;
    local openChanged = math.abs(self.openL - self.startOpenL) > 0.0001 or math.abs(self.openR - self.startOpenR) > 0.0001 or self.tears ~= self.startTears;
    result.advanced = self:getProgress() > self.startFraction + 0.0001 or openChanged or newRibs or organsChanged;
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
