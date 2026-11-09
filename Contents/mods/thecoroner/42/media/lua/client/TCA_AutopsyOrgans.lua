require "TCA_AutopsyUI";
require "TCA_Autopsy";
require "TCA_Organs";

TCA_AutopsyUI.ATTACH_MAX_STEP = 8;
TCA_AutopsyUI.ATTACH_DOT_STEP = 4;
TCA_AutopsyUI.EXTRACT_DIST = 80;
TCA_AutopsyUI.ORGAN_ROUGH_SPEED = 0.5;
TCA_AutopsyUI.ORGAN_FLY_MS = 350;
TCA_AutopsyUI.ORGAN_SNAP_MS = 150;
TCA_AutopsyUI.ORGAN_LOOK_LEVEL = 3;
TCA_AutopsyUI.ORGAN_DETAIL_LEVEL = 6;

local O_WHITE = { r = 1, g = 1, b = 1 };
local O_GREEN = { r = 0.2, g = 0.9, b = 0.3 };
local O_GAP = { r = 0.12, g = 0.02, b = 0.02 };
local O_TIP_TITLE = { r = 1, g = 1, b = 1 };
local O_TIP_TEXT = { r = 0.8, g = 0.8, b = 0.8 };
local O_TIP_STATUS = { r = 0.55, g = 0.9, b = 0.6 };

local function odist(x1, y1, x2, y2)
    local dx = x2 - x1;
    local dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
end

local function oproject(px, py, ax, ay, bx, by)
    local vx = bx - ax;
    local vy = by - ay;
    local len2 = math.max(vx * vx + vy * vy, 0.0001);
    local t = ((px - ax) * vx + (py - ay) * vy) / len2;
    if t < 0 then
        t = 0;
    elseif t > 1 then
        t = 1;
    end
    return t, odist(px, py, ax + vx * t, ay + vy * t);
end

local function oclamp01(v)
    if v < 0 then
        return 0;
    end
    if v > 1 then
        return 1;
    end
    return v;
end

function TCA_AutopsyUI:initOrgans(body)
    local A = TCA.Autopsy;
    local organState = { done = 0, damage = 0 };
    self.organDecay = 0;
    self.organZombie = false;
    if body then
        organState = A.getOrganState(body);
        self.organDecay = A.getOrganDecay(body);
        self.organZombie = TCA.isInfected(body);
    end
    self.plastronRemoved = body ~= nil and TCA.Autopsy.getStep(body) >= TCA.Autopsy.STEP_CHEST;
    self.startPlastron = self.plastronRemoved;
    self.plastronTex = getTexture(TCA.Organs.PLASTRON.texture);
    self.organsDone = organState.done;
    self.organDamage = organState.damage;
    self.startOrgansDone = self.organsDone;
    self.startOrganDamage = self.organDamage;
    self.stepLayers = {};
    for i = 1, #TCA.Organs.LIST + 2 do
        self.stepLayers[i] = getTexture("media/textures/torso_step" .. i .. ".png");
    end
    self.organTextures = {};
    for i, organ in ipairs(TCA.Organs.LIST) do
        self.organTextures[i] = getTexture(organ.texture);
    end
    self.hasScalpel = false;
    self:resetCurrentOrgan();
    self:loadAttachWork(organState.attach);
end

function TCA_AutopsyUI:loadAttachWork(str)
    local organ = self:getCurrentOrgan();
    if not organ then
        return;
    end
    local work = TCA.Autopsy.decodeAttach(str, #organ.attaches);
    for i = 1, #organ.attaches do
        self.attachWork[i] = work[i];
        self.attachCut[i] = work[i] >= 1;
    end
    self.startAttach = TCA.Autopsy.encodeAttach(self.attachWork);
end

function TCA_AutopsyUI:getAttachString()
    return TCA.Autopsy.encodeAttach(self.attachWork);
end

function TCA_AutopsyUI:resetCurrentOrgan()
    self.attachCut = {};
    self.attachWork = {};
    local organ = self:getCurrentOrgan();
    if organ then
        for i = 1, #organ.attaches do
            self.attachCut[i] = false;
            self.attachWork[i] = 0;
        end
    end
    self.attachActive = nil;
    self.organDrag = nil;
    self.organSnap = nil;
    self.startAttach = "";
end

function TCA_AutopsyUI:getStageAfterChest()
    if self.organsDone < #TCA.Organs.LIST then
        return "organs";
    end
    return "done";
end

function TCA_AutopsyUI:getCurrentOrgan()
    return TCA.Organs.LIST[self.organsDone + 1];
end

function TCA_AutopsyUI:countAttachesLeft()
    local organ = self:getCurrentOrgan();
    if not organ then
        return 0;
    end
    local left = 0;
    for i = 1, #organ.attaches do
        if not self.attachCut[i] then
            left = left + 1;
        end
    end
    return left;
end

function TCA_AutopsyUI:needsScalpelForOrgans()
    return self.stage == "organs" and self:countAttachesLeft() > 0 and not self.organDrag;
end

function TCA_AutopsyUI:refreshOrganTools()
    if self.stage == "organs" and not self.cutting then
        self.hasScalpel = TCA.Autopsy.findScalpel(self.character) ~= nil;
    end
end

function TCA_AutopsyUI:getAttachSegmentScreen(index)
    local point = self:getCurrentOrgan().attaches[index];
    local ax, ay = self:toScreen(point.ax, point.ay);
    local bx, by = self:toScreen(point.bx, point.by);
    return ax, ay, bx, by;
end

function TCA_AutopsyUI:getAttachStartScreen(index)
    local ax, ay, bx, by = self:getAttachSegmentScreen(index);
    local t = self.attachWork[index];
    return ax + (bx - ax) * t, ay + (by - ay) * t;
end

function TCA_AutopsyUI:findAttachAt(x, y)
    local organ = self:getCurrentOrgan();
    if not organ then
        return nil;
    end
    local best = nil;
    local bestDist = TCA_AutopsyUI.START_RADIUS;
    for i = 1, #organ.attaches do
        if not self.attachCut[i] then
            local sx, sy = self:getAttachStartScreen(i);
            local d = odist(x, y, sx, sy);
            if d <= bestDist then
                best = i;
                bestDist = d;
            end
        end
    end
    return best;
end

function TCA_AutopsyUI:isOverOrgan(organ, x, y)
    local bx, by = self:toBody(x, y);
    return TCA.Organs.isVisibleAt(organ, bx, by, self.organsDone);
end

function TCA_AutopsyUI:getHoverOrgan()
    if self.organDrag or self.organSnap or self.organFly then
        return nil;
    end
    local x = self:getMouseX();
    local y = self:getMouseY();
    if self:isToolShown() then
        x = self.bladeX;
        y = self.bladeY;
    end
    local bx, by = self:toBody(x, y);
    return TCA.Organs.getFrontOrganAt(bx, by, self.organsDone);
end

function TCA_AutopsyUI:damageOrgan(key)
    self.organDamage = self.organDamage + 1;
    HaloTextHelper.addBadText(self.character, getText(key));
end

function TCA_AutopsyUI:organMouseDown(x, y)
    local organ = self:getCurrentOrgan();
    if not organ or self.organFly then
        return;
    end
    if self:countAttachesLeft() > 0 then
        if not self.hasScalpel then
            return;
        end
        local index = self:findAttachAt(self.bladeX, self.bladeY);
        if index then
            self.cutting = true;
            self.attachActive = index;
            self.lastMouseX = x;
            self.lastMouseY = y;
            self.lastTime = getTimestampMs();
        elseif self:isOverOrgan(organ, self.bladeX, self.bladeY) then
            HaloTextHelper.addBadText(self.character, getText("IGUI_TCA_OrganStillAttached"));
        end
        return;
    end
    if self:isOverOrgan(organ, x, y) then
        self.cutting = true;
        self.organSnap = nil;
        self.organDrag = { grabX = x, grabY = y, dx = 0, dy = 0, speed = 0, rough = false };
        self.lastMouseX = x;
        self.lastMouseY = y;
        self.lastTime = getTimestampMs();
    end
end

function TCA_AutopsyUI:organRelease()
    self.attachActive = nil;
    if self.organDrag then
        self.organSnap = { dx = self.organDrag.dx, dy = self.organDrag.dy, time = getTimestampMs() };
        self.organDrag = nil;
    end
end

function TCA_AutopsyUI:attachSlip(key)
    self.attachActive = nil;
    self.cutting = false;
    self.flashTime = getTimestampMs();
    self:damageOrgan(key);
end

function TCA_AutopsyUI:updateAttachCut()
    local index = self.attachActive;
    if self.speed > TCA_AutopsyUI.MAX_SPEED then
        self:attachSlip("IGUI_TCA_OrganTooFast");
        return;
    end
    local ax, ay, bx, by = self:getAttachSegmentScreen(index);
    local t, d = oproject(self.bladeX, self.bladeY, ax, ay, bx, by);
    if d > TCA_AutopsyUI.SLIP_DIST then
        self:attachSlip("IGUI_TCA_OrganNick");
        return;
    end
    if d > TCA_AutopsyUI.WARN_DIST then
        self.warn = true;
        return;
    end
    local work = self.attachWork[index];
    local len = odist(ax, ay, bx, by);
    if t > work and (t - work) * len <= TCA_AutopsyUI.ATTACH_MAX_STEP then
        self.attachWork[index] = t;
    end
    if self.attachWork[index] >= TCA_AutopsyUI.SEGMENT_DONE then
        self.attachWork[index] = 1;
        self.attachCut[index] = true;
        self.attachActive = nil;
        self.cutting = false;
    end
end

function TCA_AutopsyUI:updateOrganDrag()
    local drag = self.organDrag;
    drag.dx = self:getMouseX() - drag.grabX;
    drag.dy = self:getMouseY() - drag.grabY;
    drag.speed = drag.speed * 0.7 + self.speed * 0.3;
    if drag.speed > TCA_AutopsyUI.ORGAN_ROUGH_SPEED * 0.75 then
        self.warn = true;
    end
    if drag.speed > TCA_AutopsyUI.ORGAN_ROUGH_SPEED and not drag.rough then
        drag.rough = true;
        self:damageOrgan("IGUI_TCA_OrganRough");
    end
    if odist(0, 0, drag.dx, drag.dy) >= TCA_AutopsyUI.EXTRACT_DIST then
        self:extractOrgan();
    end
end

function TCA_AutopsyUI:extractOrgan()
    local index = self.organsDone + 1;
    local drag = self.organDrag;
    self.organFly = { piece = TCA.Organs.LIST[index], tex = self.organTextures[index], dx = drag.dx, dy = drag.dy, time = getTimestampMs() };
    self.organDrag = nil;
    self.cutting = false;
    self.organsDone = index;
    self:resetCurrentOrgan();
    self:commitProgress();
end

function TCA_AutopsyUI:commitProgress()
    local result = self:collectResult();
    if not result.advanced then
        return;
    end
    TCA_Client.commitAutopsy(self.character, self.tableObject, result);
    self.startFraction = self:getProgress();
    self.startOpenL = self.openL;
    self.startOpenR = self.openR;
    self.startTears = self.tears;
    self.startRibCount = TCA.Autopsy.countRibs(self.ribs);
    self.startOrgansDone = self.organsDone;
    self.startOrganDamage = self.organDamage;
    self.startAttach = result.attach;
    self.startPlastron = self.plastronRemoved;
end

function TCA_AutopsyUI:updateOrgans()
    if self.organFly and getTimestampMs() - self.organFly.time >= TCA_AutopsyUI.ORGAN_FLY_MS then
        self.organFly = nil;
    end
    if self.organSnap and getTimestampMs() - self.organSnap.time >= TCA_AutopsyUI.ORGAN_SNAP_MS then
        self.organSnap = nil;
    end
    if not self.organFly and self.organsDone >= #TCA.Organs.LIST then
        self:setStage("done");
        return;
    end
    if not self.cutting then
        return;
    end
    if self.attachActive then
        self:updateAttachCut();
    elseif self.organDrag then
        self:updateOrganDrag();
    end
end

function TCA_AutopsyUI:getStepLayer(step)
    return self.stepLayers[math.max(1, math.min(step, #self.stepLayers))];
end

function TCA_AutopsyUI:drawPieceTexture(piece, tex, offX, offY, alpha)
    if not piece or not tex then
        return;
    end
    local x, y = self:toScreen(piece.x, piece.y);
    self:drawTextureScaled(tex, x + offX, y + offY, piece.w * self.scale, piece.h * self.scale, alpha, 1, 1, 1);
end

function TCA_AutopsyUI:drawOrganTexture(index, offX, offY, alpha)
    self:drawPieceTexture(TCA.Organs.LIST[index], self.organTextures[index], offX, offY, alpha);
end

function TCA_AutopsyUI:drawOrganLayers()
    local current = 2 + self.organsDone;
    if self.stage == "done" then
        self:drawLayer(self:getStepLayer(current), 1);
        if self.organFly then
            self:drawOrganFly();
        end
        return;
    end
    local moving = nil;
    local offX = 0;
    local offY = 0;
    if self.organDrag then
        moving = self.organsDone + 1;
        offX = self.organDrag.dx;
        offY = self.organDrag.dy;
    elseif self.organSnap then
        moving = self.organsDone + 1;
        local t = 1 - oclamp01((getTimestampMs() - self.organSnap.time) / TCA_AutopsyUI.ORGAN_SNAP_MS);
        offX = self.organSnap.dx * t;
        offY = self.organSnap.dy * t;
    end
    if moving then
        self:drawLayer(self:getStepLayer(current + 1), 1);
        self:drawOrganTexture(moving, offX, offY, 1);
    else
        self:drawLayer(self:getStepLayer(current), 1);
    end
    if self.organFly then
        self:drawOrganFly();
    end
end

function TCA_AutopsyUI:drawOrganFly()
    local fly = self.organFly;
    local t = oclamp01((getTimestampMs() - fly.time) / TCA_AutopsyUI.ORGAN_FLY_MS);
    local len = math.max(odist(0, 0, fly.dx, fly.dy), 1);
    local extra = 60 * t;
    local offX = fly.dx + fly.dx / len * extra;
    local offY = fly.dy + fly.dy / len * extra;
    self:drawPieceTexture(fly.piece, fly.tex, offX, offY, 1 - t);
end

function TCA_AutopsyUI:drawOrganOutline(organ, c, alpha)
    local cell = self.scale;
    for _, point in ipairs(TCA.Organs.getPieceOutline(organ)) do
        local x, y = self:toScreen(point.x, point.y);
        self:drawRect(x, y, cell, cell, alpha, c.r, c.g, c.b);
    end
end

function TCA_AutopsyUI:drawAttaches()
    local organ = self:getCurrentOrgan();
    if not organ or self.organDrag or self.organSnap then
        return;
    end
    local pulse = 0.5 + 0.5 * math.sin(getTimestampMs() / 200);
    local hover = nil;
    if not self.cutting and self.hasScalpel then
        hover = self:findAttachAt(self.bladeX, self.bladeY);
    end
    for i = 1, #organ.attaches do
        local ax, ay, bx, by = self:getAttachSegmentScreen(i);
        local work = self.attachWork[i];
        local cx = ax + (bx - ax) * work;
        local cy = ay + (by - ay) * work;
        if work > 0 then
            self:thickLineScreen(ax, ay, cx, cy, 3, O_GAP, 0.9);
        end
        if not self.attachCut[i] then
            local len = odist(ax, ay, bx, by);
            local count = math.max(math.floor(len / TCA_AutopsyUI.ATTACH_DOT_STEP), 1);
            for k = 0, count do
                local t = k / count;
                if t >= work then
                    local x = ax + (bx - ax) * t;
                    local y = ay + (by - ay) * t;
                    self:drawRect(x - 1, y - 1, 2, 2, 0.85, O_WHITE.r, O_WHITE.g, O_WHITE.b);
                end
            end
            local c = O_WHITE;
            local haloA = 0.2;
            if i == hover or i == self.attachActive then
                c = O_GREEN;
                haloA = 0.5;
            end
            self:fillCircleScreen(cx, cy, 3 + pulse * 2, c, haloA);
        end
    end
end

function TCA_AutopsyUI:drawOrgans()
    local current = self:getCurrentOrgan();
    if not current then
        return;
    end
    local hover = self:getHoverOrgan();
    if not self.organDrag and not self.organSnap and not self.organFly then
        local pulse = 0.5 + 0.5 * math.sin(getTimestampMs() / 300);
        if hover == current then
            self:drawOrganOutline(current, O_GREEN, 0.75);
        else
            self:drawOrganOutline(current, O_GREEN, 0.12 + 0.18 * pulse);
            if hover then
                self:drawOrganOutline(hover, O_WHITE, 0.55);
            end
        end
    end
    self:drawAttaches();
end

function TCA_AutopsyUI:getOrganTooltipLines(organ)
    local lines = {};
    table.insert(lines, { text = getText("IGUI_TCA_Organ_" .. organ.id), color = O_TIP_TITLE });
    local level = self.character:getPerkLevel(Perks.Doctor);
    if level >= TCA_AutopsyUI.ORGAN_LOOK_LEVEL then
        table.insert(lines, { text = getText("IGUI_TCA_OrganLook", getText("IGUI_TCA_OrganLook_" .. self.organDecay)), color = O_TIP_TEXT });
    end
    if level >= TCA_AutopsyUI.ORGAN_DETAIL_LEVEL then
        table.insert(lines, { text = getText("IGUI_TCA_OrganDetail_" .. self.organDecay), color = O_TIP_TEXT });
        if self.organZombie then
            table.insert(lines, { text = getText("IGUI_TCA_OrganInfected"), color = O_TIP_TEXT });
        end
    end
    if organ == self:getCurrentOrgan() then
        local left = self:countAttachesLeft();
        if left > 0 then
            table.insert(lines, { text = getText("IGUI_TCA_OrganAttached", left), color = O_TIP_STATUS });
        else
            table.insert(lines, { text = getText("IGUI_TCA_OrganFree"), color = O_TIP_STATUS });
        end
    end
    return lines;
end

function TCA_AutopsyUI:drawOrganTooltip()
    if self.stage ~= "organs" or self.cutting or self:getMissingToolText() then
        return;
    end
    local organ = self:getHoverOrgan();
    if not organ then
        return;
    end
    local lines = self:getOrganTooltipLines(organ);
    local tm = getTextManager();
    local lineH = tm:getFontHeight(UIFont.Small);
    local boxW = 0;
    for _, line in ipairs(lines) do
        boxW = math.max(boxW, tm:MeasureStringX(UIFont.Small, line.text));
    end
    boxW = boxW + 12;
    local boxH = #lines * lineH + 8;
    local anchorX = self:getMouseX();
    local anchorY = self:getMouseY();
    if self:isToolShown() then
        anchorX = self.bladeX;
        anchorY = self.bladeY;
    end
    local x = anchorX + 18;
    local y = anchorY + 18;
    if x + boxW > self.width - 4 then
        x = anchorX - boxW - 12;
    end
    if y + boxH > self.height - 4 then
        y = anchorY - boxH - 8;
    end
    self:drawRect(x, y, boxW, boxH, 0.9, 0.05, 0.05, 0.06);
    self:drawRectBorder(x, y, boxW, boxH, 1, 0.45, 0.45, 0.5);
    for i, line in ipairs(lines) do
        self:drawText(line.text, x + 6, y + 4 + (i - 1) * lineH, line.color.r, line.color.g, line.color.b, 1, UIFont.Small);
    end
end

function TCA_AutopsyUI:getOrganInstructionText()
    if self:countAttachesLeft() > 0 then
        return getText("IGUI_TCA_InstrAttach");
    end
    return getText("IGUI_TCA_InstrExtract");
end

function TCA_AutopsyUI:drawOrganInfo(infoY, smallH)
    self:drawText(getText("IGUI_TCA_OrgansDone", self.organsDone, #TCA.Organs.LIST), 20, infoY, 1, 1, 1, 1, UIFont.Small);
    self:drawText(getText("IGUI_TCA_OrgansDamaged", self.organDamage), 20, infoY + smallH, 1, 1, 1, 1, UIFont.Small);
end

function TCA_AutopsyUI:isOverPlastron(x, y)
    local bx, by = self:toBody(x, y);
    return TCA.Organs.contains(TCA.Organs.PLASTRON, bx, by);
end

function TCA_AutopsyUI:plastronMouseDown(x, y)
    if self.organFly or not self:isOverPlastron(x, y) then
        return;
    end
    self.cutting = true;
    self.organSnap = nil;
    self.organDrag = { grabX = x, grabY = y, dx = 0, dy = 0, speed = 0, rough = false };
    self.lastMouseX = x;
    self.lastMouseY = y;
    self.lastTime = getTimestampMs();
end

function TCA_AutopsyUI:updatePlastron()
    if self.organSnap and getTimestampMs() - self.organSnap.time >= TCA_AutopsyUI.ORGAN_SNAP_MS then
        self.organSnap = nil;
    end
    if not self.cutting or not self.organDrag then
        return;
    end
    local drag = self.organDrag;
    drag.dx = self:getMouseX() - drag.grabX;
    drag.dy = self:getMouseY() - drag.grabY;
    if odist(0, 0, drag.dx, drag.dy) >= TCA_AutopsyUI.EXTRACT_DIST then
        self:extractPlastron();
    end
end

function TCA_AutopsyUI:extractPlastron()
    local drag = self.organDrag;
    self.organFly = { piece = TCA.Organs.PLASTRON, tex = self.plastronTex, dx = drag.dx, dy = drag.dy, time = getTimestampMs() };
    self.organDrag = nil;
    self.organSnap = nil;
    self.cutting = false;
    self.plastronRemoved = true;
    self:setStage(self:getStageAfterChest());
end

function TCA_AutopsyUI:getPlastronOffset()
    if self.organDrag then
        return true, self.organDrag.dx, self.organDrag.dy;
    end
    if self.organSnap then
        local t = 1 - oclamp01((getTimestampMs() - self.organSnap.time) / TCA_AutopsyUI.ORGAN_SNAP_MS);
        return true, self.organSnap.dx * t, self.organSnap.dy * t;
    end
    return false, 0, 0;
end

function TCA_AutopsyUI:drawPlastronLayers()
    local moving, offX, offY = self:getPlastronOffset();
    if moving then
        self:drawLayer(self.layerChest, 1);
        self:drawPieceTexture(TCA.Organs.PLASTRON, self.plastronTex, offX, offY, 1);
        return;
    end
    self:drawLayer(self.layerOpened, 1);
end

function TCA_AutopsyUI:drawPlastron()
    local moving = self:getPlastronOffset();
    if moving then
        return;
    end
    self:drawRibs();
    local cell = self.scale;
    local alpha = 0.12 + 0.18 * (0.5 + 0.5 * math.sin(getTimestampMs() / 300));
    if self:isOverPlastron(self:getMouseX(), self:getMouseY()) then
        alpha = 0.75;
    end
    for _, point in ipairs(TCA.Organs.getPieceOutline(TCA.Organs.PLASTRON)) do
        local x, y = self:toScreen(point.x, point.y);
        self:drawRect(x, y, cell, cell, alpha, O_GREEN.r, O_GREEN.g, O_GREEN.b);
    end
end
