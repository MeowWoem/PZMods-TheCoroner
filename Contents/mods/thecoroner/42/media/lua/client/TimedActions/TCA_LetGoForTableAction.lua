require "TimedActions/ISBaseTimedAction";

TCA_LetGoForTableAction = ISBaseTimedAction:derive("TCA_LetGoForTableAction");

function TCA_LetGoForTableAction:isValid()
    return self.character:isDraggingCorpse();
end

function TCA_LetGoForTableAction:waitToStart()
    self.character:faceThisObject(self.tableObject);
    return self.character:shouldBeTurning();
end

function TCA_LetGoForTableAction:start()
    self.action:setAllowedWhileDraggingCorpses(true);
end

function TCA_LetGoForTableAction:perform()
    TCA_Client.waitForDroppedBody(self.character, self.tableObject);
    self.character:setDoGrappleLetGo();
    ISBaseTimedAction.perform(self);
end

function TCA_LetGoForTableAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 5;
end

function TCA_LetGoForTableAction:new(character, tableObject)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.maxTime = o:getDuration();
    o.forceProgressBar = true;
    o.allowedWhileDraggingCorpses = true;
    return o;
end
