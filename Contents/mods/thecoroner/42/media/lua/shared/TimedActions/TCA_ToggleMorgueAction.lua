require "TimedActions/ISBaseTimedAction";
require "TCA_Morgue";

TCA_ToggleMorgueAction = ISBaseTimedAction:derive("TCA_ToggleMorgueAction");

function TCA_ToggleMorgueAction:isValid()
    if not self.object or not self.object:getSquare() then
        return false;
    end
    if self.object:getObjectIndex() < 0 then
        return false;
    end
    return TCA.Morgue.isDrawer(self.object);
end

function TCA_ToggleMorgueAction:waitToStart()
    self.character:faceThisObject(self.object);
    return self.character:shouldBeTurning();
end

function TCA_ToggleMorgueAction:update()
    self.character:faceThisObject(self.object);
end

function TCA_ToggleMorgueAction:start()
    self:setActionAnim("Loot");
    self:setAnimVariable("LootPosition", "Mid");
end

function TCA_ToggleMorgueAction:stop()
    ISBaseTimedAction.stop(self);
end

function TCA_ToggleMorgueAction:perform()
    self.object:getSquare():playSound("LightSwitch");
    ISBaseTimedAction.perform(self);
end

function TCA_ToggleMorgueAction:complete()
    TCA.Morgue.setPowered(self.object, self.turnOn);
    return true;
end

function TCA_ToggleMorgueAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 20;
end

function TCA_ToggleMorgueAction:new(character, object, turnOn)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.object = object;
    o.turnOn = turnOn;
    o.maxTime = o:getDuration();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    return o;
end
