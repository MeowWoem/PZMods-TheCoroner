require "TCA_Sound";
require "TCA_AutopsyUI";

TCA_AutopsyUI.SND_OSC_START = "TCA_OscStart";
TCA_AutopsyUI.SND_OSC_IDLE = "TCA_OscIdleLoop";
TCA_AutopsyUI.SND_OSC_CUT_START = "TCA_OscCutStart";
TCA_AutopsyUI.SND_OSC_CUT = "TCA_OscCutLoop";
TCA_AutopsyUI.SND_OSC_CUT_STOP = "TCA_OscCutStop";
TCA_AutopsyUI.SND_OSC_STOP = "TCA_OscStop";
TCA_AutopsyUI.SND_SCALPEL = "TCA_Scalpel";

TCA_AutopsyUI.SND_SCALPEL_HOLD_MS = 150;
TCA_AutopsyUI.SND_SCALPEL_MIN_MS = 450;
TCA_AutopsyUI.SND_SCALPEL_MAX_MS = 750;
TCA_AutopsyUI.SND_SCALPEL_FADE_MS = 150;
TCA_AutopsyUI.SND_IDLE_FADE_MS = 80;

function TCA_AutopsyUI:initSound()
    local snd = {};
    snd.osc = nil;
    snd.scalpelIds = {};
    snd.scalpelLastCut = 0;
    snd.scalpelNext = 0;
    snd.lastMetric = nil;
    snd.lastStage = nil;
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

function TCA_AutopsyUI:updateSound()
    if not self.snd then
        self:initSound();
    end
    self:updateOscillating();
    self:updateScalpel();
end

function TCA_AutopsyUI:stopSounds()
    if not self.snd then
        return;
    end
    self:stopOscillating(true);
    self:stopScalpel();
end
