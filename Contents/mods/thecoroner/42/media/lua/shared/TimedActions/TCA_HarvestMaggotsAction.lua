require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_Exam";

TCA_HarvestMaggotsAction = ISBaseTimedAction:derive("TCA_HarvestMaggotsAction");

function TCA_HarvestMaggotsAction:isValid()
    return TCA.findBodyAt(self.bx, self.by, self.bz) ~= nil;
end

function TCA_HarvestMaggotsAction:waitToStart()
    self.character:faceLocation(self.bx, self.by);
    return self.character:shouldBeTurning();
end

function TCA_HarvestMaggotsAction:update()
    self.character:faceLocation(self.bx, self.by);
end

function TCA_HarvestMaggotsAction:start()
    self:setActionAnim("Loot");
end

function TCA_HarvestMaggotsAction:stop()
    ISBaseTimedAction.stop(self);
end

function TCA_HarvestMaggotsAction:perform()
    ISBaseTimedAction.perform(self);
end

function TCA_HarvestMaggotsAction:complete()
    local E = TCA.Exam;
    local body = TCA.findBodyAt(self.bx, self.by, self.bz);
    if not body then
        return true;
    end
    local count = E.getHarvestCount(body);
    if count <= 0 then
        return true;
    end
    local inv = self.character:getInventory();
    for i = 1, count do
        local item = instanceItem(E.MAGGOT_ITEM);
        if item then
            inv:AddItem(item);
            if isServer() then
                sendAddItemToContainer(inv, item);
            end
        end
    end
    body:getModData()[E.KEY_MAGGOTS] = true;
    body:transmitModData();
    return true;
end

function TCA_HarvestMaggotsAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 150;
end

function TCA_HarvestMaggotsAction:new(character, bx, by, bz)
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
