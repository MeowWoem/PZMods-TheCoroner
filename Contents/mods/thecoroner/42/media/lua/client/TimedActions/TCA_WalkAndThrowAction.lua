require "TimedActions/ISBaseTimedAction";
require "TimedActions/TCA_ThrowOntoTableAction";

TCA_WalkAndThrowAction = ISBaseTimedAction:derive("TCA_WalkAndThrowAction");

function TCA_WalkAndThrowAction:isValid()
    return self.character:isDraggingCorpse();
end

function TCA_WalkAndThrowAction:start()
    self.action:setAllowedWhileDraggingCorpses(true);
end

function TCA_WalkAndThrowAction:perform()
    if self.tableObject:getSquare() and luautils.walkAdj(self.character, self.tableObject:getSquare(), true) then
        ISTimedActionQueue.add(TCA_ThrowOntoTableAction:new(self.character, self.tableObject));
    end
    ISBaseTimedAction.perform(self);
end

function TCA_WalkAndThrowAction:getDuration()
    return 1;
end

function TCA_WalkAndThrowAction:new(character, tableObject)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.maxTime = o:getDuration();
    o.allowedWhileDraggingCorpses = true;
    return o;
end
