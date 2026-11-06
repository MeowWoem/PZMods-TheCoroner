--***********************************************************
--**  Action : retirer un cadavre d'une table              **
--**  Le corps est redescendu au sol aux pieds du joueur,  **
--**  d'ou il peut etre saisi normalement.                 **
--***********************************************************

require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";

TCA_RemoveFromTableAction = ISBaseTimedAction:derive("TCA_RemoveFromTableAction");

function TCA_RemoveFromTableAction:isValid()
    if not self.tableObject or not self.tableObject:getSquare() then
        return false;
    end
    if self.character:isDraggingCorpse() then
        return false;
    end
    return TCA.tableHasBody(self.tableObject);
end

function TCA_RemoveFromTableAction:waitToStart()
    self.character:faceThisObject(self.tableObject);
    return self.character:shouldBeTurning();
end

function TCA_RemoveFromTableAction:update()
    self.character:faceThisObject(self.tableObject);
    self.character:setMetabolicTarget(Metabolics.HeavyWork);
end

function TCA_RemoveFromTableAction:start()
    self:setActionAnim("Loot");
    self:setAnimVariable("LootPosition", "Mid");
    self.character:reportEvent("EventLootItem");
end

function TCA_RemoveFromTableAction:stop()
    ISBaseTimedAction.stop(self);
end

function TCA_RemoveFromTableAction:perform()
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self);
end

function TCA_RemoveFromTableAction:complete()
    local body = TCA.findBodyOnTable(self.tableObject);
    if not body then
        return false;
    end
    return TCA.removeBodyFromTable(body, self.character);
end

function TCA_RemoveFromTableAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 60;
end

function TCA_RemoveFromTableAction:new(character, tableObject)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.maxTime = o:getDuration();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    return o;
end
