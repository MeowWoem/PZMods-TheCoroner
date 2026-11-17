require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_Compat_ZVV";

TCA_ZVVPartAction = ISBaseTimedAction:derive("TCA_ZVVPartAction");

function TCA_ZVVPartAction:getBody()
    return TCA.findBodyAt(self.bx, self.by, self.bz);
end

function TCA_ZVVPartAction:isValid()
    local Z = TCA.Compat.ZVV;
    local inv = self.character:getInventory();
    if self:getBody() == nil or not Z.findScalpel(inv) or not Z.findSaw(inv) then
        return false;
    end
    return Z.findSack(inv) ~= nil or Z.findPlastics(inv) ~= nil;
end

function TCA_ZVVPartAction:waitToStart()
    self.character:faceLocation(self.bx, self.by);
    return self.character:shouldBeTurning();
end

function TCA_ZVVPartAction:update()
    self.character:faceLocation(self.bx, self.by);
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic);
end

function TCA_ZVVPartAction:start()
    self:setActionAnim("SawSmallItemMetal");
    self.character:SetVariable("LootPosition", "Mid");
    self.sound = self.character:getEmitter():playSound("Sawing");
end

function TCA_ZVVPartAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:getEmitter():stopSound(self.sound);
    end
    self.sound = nil;
end

function TCA_ZVVPartAction:stop()
    if self.sound then
        self.character:playSound("PutItemInBag");
    end
    self:stopSound();
    ISBaseTimedAction.stop(self);
end

function TCA_ZVVPartAction:perform()
    self:stopSound();
    ISBaseTimedAction.perform(self);
end

function TCA_ZVVPartAction:complete()
    local body = self:getBody();
    if body then
        TCA.Compat.ZVV.collectPart(self.character, body, self.itemType);
    end
    return true;
end

function TCA_ZVVPartAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return TCA.Compat.ZVV.PART_DURATION;
end

function TCA_ZVVPartAction:new(character, bx, by, bz, itemType)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.bx = bx;
    o.by = by;
    o.bz = bz;
    o.itemType = itemType;
    o.maxTime = o:getDuration();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    return o;
end
