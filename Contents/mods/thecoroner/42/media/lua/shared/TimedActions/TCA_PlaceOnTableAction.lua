require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";

TCA_PlaceOnTableAction = ISBaseTimedAction:derive("TCA_PlaceOnTableAction");

function TCA_PlaceOnTableAction:isValid()
    if not self.tableObject or not self.tableObject:getSquare() then
        return false;
    end
    if self.tableObject:getObjectIndex() < 0 then
        return false;
    end
    if not TCA.isLongTable(self.tableObject) then
        return false;
    end
    if TCA.tableHasBody(self.tableObject) then
        return false;
    end
    if TCA.getTableClutter(self.tableObject) then
        return false;
    end
    return true;
end

function TCA_PlaceOnTableAction:waitToStart()
    self.character:faceThisObject(self.tableObject);
    return self.character:shouldBeTurning();
end

function TCA_PlaceOnTableAction:update()
    self.character:faceThisObject(self.tableObject);
    self.character:setMetabolicTarget(Metabolics.HeavyWork);
end

function TCA_PlaceOnTableAction:start()
    self:setActionAnim("Loot");
    self:setAnimVariable("LootPosition", "Mid");
    self.character:reportEvent("EventLootItem");
end

function TCA_PlaceOnTableAction:stop()
    ISBaseTimedAction.stop(self);
end

function TCA_PlaceOnTableAction:perform()
    ISBaseTimedAction.perform(self);
end

function TCA_PlaceOnTableAction:complete()
    if TCA.getTableClutter(self.tableObject) then
        return false;
    end
    local body = nil;
    if self.bx then
        body = TCA.findBodyAt(self.bx, self.by, self.bz);
        if body and not TCA.isBodyNearTable(self.tableObject, body) then
            body = nil;
        end
    else
        body = TCA.findBodyNearTable(self.tableObject, self.character);
    end
    if not body then
        return false;
    end
    return TCA.placeBodyOnTable(body, self.tableObject, self.character);
end

function TCA_PlaceOnTableAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 80;
end

function TCA_PlaceOnTableAction:new(character, tableObject, bx, by, bz)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.bx = bx;
    o.by = by;
    o.bz = bz;
    o.maxTime = o:getDuration();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.allowedWhileDraggingCorpses = true;
    return o;
end
