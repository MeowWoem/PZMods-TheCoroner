require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_TableThrow";

TCA_ThrowOntoTableAction = ISBaseTimedAction:derive("TCA_ThrowOntoTableAction");

function TCA_ThrowOntoTableAction:isValid()
    if getGameSpeed() > 1 then
        return false;
    end
    return TCA.TableThrow.canThrow(self.character, self.tableObject);
end

function TCA_ThrowOntoTableAction:waitToStart()
    self.character:faceThisObject(self.tableObject);
    return self.character:shouldBeTurning();
end

function TCA_ThrowOntoTableAction:start()
    self.action:setAllowedWhileDraggingCorpses(true);
end

function TCA_ThrowOntoTableAction:complete()
    if isServer() then
        TCA.TableThrow.registerServer(self.character, self.grappledChar, self.tableObject);
    end
    return true;
end

function TCA_ThrowOntoTableAction:perform()
    local container = TCA.TableThrow.newContainer(self.tableObject);
    if not isClient() then
        TCA.TableThrow.watchLocal(self.character, self.tableObject, container);
    end
    self.character:throwGrappledIntoInventory(container);
    ISBaseTimedAction.perform(self);
end

function TCA_ThrowOntoTableAction:getDuration()
    return 5;
end

function TCA_ThrowOntoTableAction:new(character, tableObject)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.grappledChar = character:getGrapplingTarget();
    o.maxTime = o:getDuration();
    o.allowedWhileDraggingCorpses = true;
    return o;
end
