require "TimedActions/ISBaseTimedAction";
require "TCA_Thermometer";

TCA_TakeTemperatureAction = ISBaseTimedAction:derive("TCA_TakeTemperatureAction");

TCA_TakeTemperatureAction.MAX_MOVE = 1.0;
TCA_TakeTemperatureAction.MAX_RANGE = 2.0;

function TCA_TakeTemperatureAction:isSelf()
    return self.target == self.character;
end

function TCA_TakeTemperatureAction:isValid()
    if not self.target or self.target:isDead() then
        return false;
    end
    if not TCA.Thermometer.findThermometer(self.character) then
        return false;
    end
    if self:isSelf() then
        return true;
    end
    if math.abs(self.target:getX() - self.targetX) > TCA_TakeTemperatureAction.MAX_MOVE or math.abs(self.target:getY() - self.targetY) > TCA_TakeTemperatureAction.MAX_MOVE then
        return false;
    end
    return self.character:DistTo(self.target) <= TCA_TakeTemperatureAction.MAX_RANGE;
end

function TCA_TakeTemperatureAction:waitToStart()
    if self:isSelf() then
        return false;
    end
    self.character:faceThisObject(self.target);
    return self.character:shouldBeTurning();
end

function TCA_TakeTemperatureAction:update()
    if not self:isSelf() then
        self.character:faceThisObject(self.target);
    end
end

function TCA_TakeTemperatureAction:start()
    if self:isSelf() then
        self:setActionAnim(CharacterActionAnims.Bandage);
        self:setAnimVariable("BandageType", "UpperBody");
        self.character:reportEvent("EventBandage");
    else
        self:setActionAnim("MedicalCheck");
    end
end

function TCA_TakeTemperatureAction:stop()
    ISBaseTimedAction.stop(self);
end

function TCA_TakeTemperatureAction:perform()
    ISBaseTimedAction.perform(self);
end

function TCA_TakeTemperatureAction:complete()
    if not self.target or self.target:isDead() then
        return false;
    end
    TCA.Thermometer.measure(self.character, self.target);
    return true;
end

function TCA_TakeTemperatureAction:getDuration()
    return TCA.Thermometer.getDuration(self.character);
end

function TCA_TakeTemperatureAction:new(character, target)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.target = target;
    o.targetX = target:getX();
    o.targetY = target:getY();
    o.maxTime = o:getDuration();
    o.forceProgressBar = true;
    return o;
end
