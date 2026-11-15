require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_BloodType";

TCA_BloodTypeAction = ISBaseTimedAction:derive("TCA_BloodTypeAction");

function TCA_BloodTypeAction:isValid()
    if TCA.findBodyAt(self.bx, self.by, self.bz) == nil then
        return false;
    end
    if not TCA.BloodType.findKit(self.character) then
        return false;
    end
    if TCA.isTooDark(self.character) then
        TCA.warnTooDark(self);
        return false;
    end
    return true;
end

function TCA_BloodTypeAction:waitToStart()
    self.character:faceLocation(self.bx, self.by);
    return self.character:shouldBeTurning();
end

function TCA_BloodTypeAction:update()
    self.character:faceLocation(self.bx, self.by);
end

function TCA_BloodTypeAction:start()
    self:setActionAnim("Loot");
end

function TCA_BloodTypeAction:stop()
    ISBaseTimedAction.stop(self);
end

function TCA_BloodTypeAction:perform()
    ISBaseTimedAction.perform(self);
end

function TCA_BloodTypeAction:complete()
    local B = TCA.BloodType;
    local body = TCA.findBodyAt(self.bx, self.by, self.bz);
    local kit = B.findKit(self.character);
    if not body or not kit then
        return true;
    end
    kit:UseAndSync();
    B.notify(self.character, B.typeBody(self.character, body));
    return true;
end

function TCA_BloodTypeAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return TCA.BloodType.DURATION;
end

function TCA_BloodTypeAction:new(character, bx, by, bz)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.bx = bx;
    o.by = by;
    o.bz = bz;
    o.maxTime = o:getDuration();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    return o;
end
