require "TCA_Sound";
require "TCA_AutopsyUI";

TCA_AutopsyUI.SND_OSC_START = "TCA_OscStart";
TCA_AutopsyUI.SND_OSC_IDLE = "TCA_OscIdleLoop";
TCA_AutopsyUI.SND_OSC_CUT_START = "TCA_OscCutStart";
TCA_AutopsyUI.SND_OSC_CUT = "TCA_OscCutLoop";
TCA_AutopsyUI.SND_OSC_CUT_STOP = "TCA_OscCutStop";
TCA_AutopsyUI.SND_OSC_STOP = "TCA_OscStop";
TCA_AutopsyUI.SND_SCALPEL = "TCA_Scalpel";
TCA_AutopsyUI.SND_SAW_PUSH = "TCA_SawPush";
TCA_AutopsyUI.SND_SAW_PULL = "TCA_SawPull";
TCA_AutopsyUI.SND_RIB_CRACK = "TCA_RibCrack";
TCA_AutopsyUI.SND_SKIN_PEEL = "TCA_SkinPeel";
TCA_AutopsyUI.SND_SKIN_RIP = "TCA_SkinRip";

TCA_AutopsyUI.SND_SCALPEL_HOLD_MS = 150;
TCA_AutopsyUI.SND_SCALPEL_MIN_MS = 450;
TCA_AutopsyUI.SND_SCALPEL_MAX_MS = 750;
TCA_AutopsyUI.SND_SCALPEL_FADE_MS = 150;
TCA_AutopsyUI.SND_IDLE_FADE_MS = 80;
TCA_AutopsyUI.SND_SAW_STROKE_MIN = 6;
TCA_AutopsyUI.SND_SAW_FADE_MS = 60;
TCA_AutopsyUI.SND_PEEL_HOLD_MS = 150;
TCA_AutopsyUI.SND_PEEL_SLOW_MS = 750;
TCA_AutopsyUI.SND_PEEL_FAST_MS = 300;
TCA_AutopsyUI.SND_PEEL_FADE_MS = 150;

function TCA_AutopsyUI:initSound()
    local snd = {};
    snd.osc = nil;
    snd.scalpelIds = {};
    snd.scalpelLastCut = 0;
    snd.scalpelNext = 0;
    snd.lastMetric = nil;
    snd.lastStage = nil;
    snd.sawId = nil;
    snd.sawDir = 0;
    snd.sawAcc = 0;
    snd.sawFired = false;
    snd.peelIds = {};
    snd.peelLastPull = 0;
    snd.peelNext = 0;
    snd.peelLast = nil;
    self.snd = snd;
end

function TCA_AutopsyUI:wantsOscillating()
    return self.stage == "ribs" and self:isOscillating();
end

function TCA_AutopsyUI:isOscCutting()
    return self.cutting and self.ribActive ~= nil;
end

function TCA_AutopsyUI:startOscillating()
    local S = TCA.Sound;
    local osc = {};
    osc.state = "starting";
    osc.startId = S.play(self.character, TCA_AutopsyUI.SND_OSC_START);
    osc.idleId = nil;
    osc.cutStartId = nil;
    osc.cutId = nil;
    self.snd.osc = osc;
end

function TCA_AutopsyUI:startOscIdle()
    local osc = self.snd.osc;
    if osc.idleId and TCA.Sound.isPlaying(self.character, osc.idleId) then
        TCA.Sound.setVolume(self.character, osc.idleId, 1);
        return;
    end
    osc.idleId = TCA.Sound.play(self.character, TCA_AutopsyUI.SND_OSC_IDLE);
end

function TCA_AutopsyUI:stopOscCut(playStop)
    local S = TCA.Sound;
    local osc = self.snd.osc;
    if osc.cutStartId then
        S.stop(self.character, osc.cutStartId);
        osc.cutStartId = nil;
    end
    if osc.cutId then
        S.stop(self.character, osc.cutId);
        osc.cutId = nil;
    end
    if playStop then
        S.play(self.character, TCA_AutopsyUI.SND_OSC_CUT_STOP);
    end
end

function TCA_AutopsyUI:stopOscillating(playStop)
    local osc = self.snd and self.snd.osc;
    if not osc then
        return;
    end
    local S = TCA.Sound;
    self:stopOscCut(false);
    if osc.startId then
        S.stop(self.character, osc.startId);
    end
    if osc.idleId then
        S.fadeOut(self.character, osc.idleId, 1, TCA_AutopsyUI.SND_IDLE_FADE_MS);
    end
    if playStop then
        S.play(self.character, TCA_AutopsyUI.SND_OSC_STOP);
    end
    self.snd.osc = nil;
end

function TCA_AutopsyUI:updateOscillating()
    local wants = self:wantsOscillating();
    local osc = self.snd.osc;
    if not wants then
        if osc then
            self:stopOscillating(true);
        end
        return;
    end
    if not osc then
        self:startOscillating();
        osc = self.snd.osc;
    end
    local S = TCA.Sound;
    local cutting = self:isOscCutting();
    if osc.state == "starting" then
        if osc.startId and S.isPlaying(self.character, osc.startId) and not cutting then
            return;
        end
        osc.startId = nil;
        osc.state = "idle";
        self:startOscIdle();
    end
    if osc.state == "idle" then
        if cutting then
            osc.state = "cutStart";
            if osc.idleId then
                S.setVolume(self.character, osc.idleId, 0);
            end
            osc.cutStartId = S.play(self.character, TCA_AutopsyUI.SND_OSC_CUT_START);
        end
        return;
    end
    if not cutting then
        self:stopOscCut(true);
        osc.state = "idle";
        self:startOscIdle();
        return;
    end
    if osc.state == "cutStart" then
        if osc.cutStartId and S.isPlaying(self.character, osc.cutStartId) then
            return;
        end
        osc.cutStartId = nil;
        osc.state = "cut";
        osc.cutId = S.play(self.character, TCA_AutopsyUI.SND_OSC_CUT);
    end
end

function TCA_AutopsyUI:getScalpelMetric()
    if self.stage == "incision" then
        return self:getProgress();
    end
    if self.stage == "organs" and self.attachWork then
        local total = 0;
        for _, work in pairs(self.attachWork) do
            total = total + work;
        end
        return total + (self.organsDone or 0) * 100;
    end
    return nil;
end

function TCA_AutopsyUI:stopScalpel()
    local S = TCA.Sound;
    for _, id in ipairs(self.snd.scalpelIds) do
        S.fadeOut(self.character, id, 1, TCA_AutopsyUI.SND_SCALPEL_FADE_MS);
    end
    self.snd.scalpelIds = {};
    self.snd.scalpelNext = 0;
end

function TCA_AutopsyUI:updateScalpel()
    local snd = self.snd;
    local metric = self:getScalpelMetric();
    local now = getTimestampMs();
    if snd.lastStage ~= self.stage then
        snd.lastStage = self.stage;
        snd.lastMetric = metric;
    end
    if metric ~= nil and snd.lastMetric ~= nil and metric > snd.lastMetric + 0.00001 and self.cutting then
        snd.scalpelLastCut = now;
    end
    snd.lastMetric = metric;
    local active = now - snd.scalpelLastCut < TCA_AutopsyUI.SND_SCALPEL_HOLD_MS;
    if not active then
        if #snd.scalpelIds > 0 then
            self:stopScalpel();
        end
        return;
    end
    if now < snd.scalpelNext then
        return;
    end
    local id = TCA.Sound.play(self.character, TCA_AutopsyUI.SND_SCALPEL);
    if id then
        local keep = {};
        for _, old in ipairs(snd.scalpelIds) do
            if TCA.Sound.isPlaying(self.character, old) then
                table.insert(keep, old);
            end
        end
        table.insert(keep, id);
        snd.scalpelIds = keep;
    end
    snd.scalpelNext = now + TCA_AutopsyUI.SND_SCALPEL_MIN_MS + ZombRand(TCA_AutopsyUI.SND_SCALPEL_MAX_MS - TCA_AutopsyUI.SND_SCALPEL_MIN_MS + 1);
end

function TCA_AutopsyUI:isManualSawing()
    return self.stage == "ribs" and self.ribMode == "saw" and self.cutting and self.ribActive ~= nil;
end

function TCA_AutopsyUI:stopSaw()
    local snd = self.snd;
    if snd.sawId then
        TCA.Sound.fadeOut(self.character, snd.sawId, 1, TCA_AutopsyUI.SND_SAW_FADE_MS);
        snd.sawId = nil;
    end
    snd.sawDir = 0;
    snd.sawAcc = 0;
    snd.sawFired = false;
end

function TCA_AutopsyUI:updateSaw()
    local snd = self.snd;
    if not self:isManualSawing() then
        if snd.sawDir ~= 0 or snd.sawId then
            self:stopSaw();
        end
        return;
    end
    local dy = self.mouseDY or 0;
    if dy == 0 then
        return;
    end
    local dir = 1;
    if dy < 0 then
        dir = -1;
    end
    if dir ~= snd.sawDir then
        snd.sawDir = dir;
        snd.sawAcc = 0;
        snd.sawFired = false;
    end
    snd.sawAcc = snd.sawAcc + math.abs(dy);
    if snd.sawFired or snd.sawAcc < TCA_AutopsyUI.SND_SAW_STROKE_MIN then
        return;
    end
    snd.sawFired = true;
    if snd.sawId then
        TCA.Sound.fadeOut(self.character, snd.sawId, 1, TCA_AutopsyUI.SND_SAW_FADE_MS);
    end
    local name = TCA_AutopsyUI.SND_SAW_PULL;
    if dir < 0 then
        name = TCA_AutopsyUI.SND_SAW_PUSH;
    end
    snd.sawId = TCA.Sound.play(self.character, name);
end

function TCA_AutopsyUI:stopPeel()
    local snd = self.snd;
    for _, id in ipairs(snd.peelIds) do
        TCA.Sound.fadeOut(self.character, id, 1, TCA_AutopsyUI.SND_PEEL_FADE_MS);
    end
    snd.peelIds = {};
    snd.peelNext = 0;
end

function TCA_AutopsyUI:getPeelInterval()
    local t = 0;
    if TCA_AutopsyUI.TEAR_SPEED and TCA_AutopsyUI.TEAR_SPEED > 0 then
        t = math.max(0, math.min(1, (self.pullSpeed or 0) / TCA_AutopsyUI.TEAR_SPEED));
    end
    local slow = TCA_AutopsyUI.SND_PEEL_SLOW_MS;
    local fast = TCA_AutopsyUI.SND_PEEL_FAST_MS;
    return slow + (fast - slow) * t;
end

function TCA_AutopsyUI:updatePeel()
    local snd = self.snd;
    local now = getTimestampMs();
    local metric = nil;
    if self.stage == "open" then
        metric = (self.openL or 0) + (self.openR or 0);
    end
    if metric ~= nil and snd.peelLast ~= nil and metric > snd.peelLast + 0.00001 and self.cutting and self.pullSide then
        snd.peelLastPull = now;
    end
    snd.peelLast = metric;
    local active = now - snd.peelLastPull < TCA_AutopsyUI.SND_PEEL_HOLD_MS;
    if not active then
        if #snd.peelIds > 0 then
            self:stopPeel();
        end
        return;
    end
    if now < snd.peelNext then
        return;
    end
    local id = TCA.Sound.play(self.character, TCA_AutopsyUI.SND_SKIN_PEEL);
    if id then
        local keep = {};
        for _, old in ipairs(snd.peelIds) do
            if TCA.Sound.isPlaying(self.character, old) then
                table.insert(keep, old);
            end
        end
        table.insert(keep, id);
        snd.peelIds = keep;
    end
    local interval = self:getPeelInterval();
    snd.peelNext = now + interval * (0.85 + ZombRand(31) / 100);
end

function TCA_AutopsyUI:playSkinRip()
    if self.snd then
        self:stopPeel();
        self.snd.peelLastPull = 0;
    end
    TCA.Sound.play(self.character, TCA_AutopsyUI.SND_SKIN_RIP);
end

function TCA_AutopsyUI:playRibCrack()
    TCA.Sound.play(self.character, TCA_AutopsyUI.SND_RIB_CRACK);
end

function TCA_AutopsyUI:updateSound()
    if not self.snd then
        self:initSound();
    end
    self:updateOscillating();
    self:updateScalpel();
    self:updateSaw();
    self:updatePeel();
end

function TCA_AutopsyUI:stopSounds()
    if not self.snd then
        return;
    end
    self:stopOscillating(true);
    self:stopScalpel();
    self:stopSaw();
    self:stopPeel();
end
