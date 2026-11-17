require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_Compat_ZVV";

TCA_ZVVAutopsyAction = ISBaseTimedAction:derive("TCA_ZVVAutopsyAction");

function TCA_ZVVAutopsyAction:getBody()
    return TCA.findBodyAt(self.bx, self.by, self.bz);
end

function TCA_ZVVAutopsyAction:isValid()
    local inv = self.character:getInventory();
    return self:getBody() ~= nil and TCA.Compat.ZVV.findScalpel(inv) ~= nil and TCA.Compat.ZVV.findTweezers(inv) ~= nil;
end

function TCA_ZVVAutopsyAction:waitToStart()
    self.character:faceLocation(self.bx, self.by);
    return self.character:shouldBeTurning();
end

function TCA_ZVVAutopsyAction:update()
    self.character:faceLocation(self.bx, self.by);
    self.character:setMetabolicTarget(Metabolics.MediumWork);
end

function TCA_ZVVAutopsyAction:start()
    self:setActionAnim("Loot");
    if self.onTable then
        self.character:SetVariable("LootPosition", "Mid");
    else
        self.character:SetVariable("LootPosition", "Low");
    end
    local gain = 1;
    if LabModOptions and LabModOptions.getAutopsySoundGain then
        gain = LabModOptions.getAutopsySoundGain();
    end
    if gain <= 0 then
        return;
    end
    local emitter = self.character:getEmitter();
    self.sound = emitter:playSound("Meat_A");
    if self.sound and gain < 1 then
        emitter:setVolume(self.sound, gain);
    end
end

function TCA_ZVVAutopsyAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound);
    end
    self.sound = nil;
end

function TCA_ZVVAutopsyAction:stop()
    self:stopSound();
    ISBaseTimedAction.stop(self);
end

function TCA_ZVVAutopsyAction:perform()
    self:stopSound();
    ISBaseTimedAction.perform(self);
end

function TCA_ZVVAutopsyAction:complete()
    local body = self:getBody();
    if body then
        TCA.Compat.ZVV.doAutopsy(self.character, body);
    end
    return true;
end

function TCA_ZVVAutopsyAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return TCA.Compat.ZVV.getAutopsyDuration(self.character, self.onTable);
end

function TCA_ZVVAutopsyAction:new(character, bx, by, bz, onTable)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.bx = bx;
    o.by = by;
    o.bz = bz;
    o.onTable = onTable == true;
    o.maxTime = o:getDuration();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    return o;
end
