require "TimedActions/ISBaseTimedAction";
require "TimedActions/ISTimedActionQueue";
require "TCA_Shared";
require "TCA_Autopsy";

TCA_AutopsyAction = ISBaseTimedAction:derive("TCA_AutopsyAction");

function TCA_AutopsyAction:isValid()
    if not self.tableObject or not self.tableObject:getSquare() then
        return false;
    end
    local body = TCA.findBodyOnTable(self.tableObject);
    if not body then
        return false;
    end
    if TCA.Autopsy.getBlockingClothing(body) then
        return false;
    end
    if self.ui then
        return true;
    end
    local stage = TCA.Autopsy.getStage(body);
    if stage == "done" then
        return false;
    end
    return TCA.Autopsy.hasToolForStage(self.character, stage);
end

function TCA_AutopsyAction:waitToStart()
    self.character:faceThisObject(self.tableObject);
    return self.character:shouldBeTurning();
end

function TCA_AutopsyAction:update()
    self.character:faceThisObject(self.tableObject);
    self.character:setMetabolicTarget(Metabolics.LightWork);
    if self.ui and self.ui.finished then
        self:forceComplete();
    end
end

function TCA_AutopsyAction:start()
    self:setActionAnim("Loot");
    self:setAnimVariable("LootPosition", "Mid");
    self.ui = TCA_AutopsyUI.open(self.character, self.tableObject);
end

function TCA_AutopsyAction:closeUI(insertNow)
    if not self.ui then
        return;
    end
    local result = self.ui:collectResult();
    self.ui:closeSilently();
    self.ui = nil;
    if not result.advanced then
        return;
    end
    local action = TCA_AutopsyResultAction:new(self.character, self.tableObject, result.segIndex, result.segProgress, result.accuracy, result.paths, result.openL, result.openR, result.tears, result.ribs, result.accSamples, result.organs, result.organDamage, result.plastron, result.attach, result.cuts);
    if insertNow and ISTimedActionQueue.addAfter(self, action) then
        return;
    end
    TCA_Client.queueNextTick(action);
end

function TCA_AutopsyAction:stop()
    self:closeUI(false);
    ISBaseTimedAction.stop(self);
end

function TCA_AutopsyAction:perform()
    self:closeUI(true);
    ISBaseTimedAction.perform(self);
end

function TCA_AutopsyAction:new(character, tableObject)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.maxTime = -1;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
    return o;
end
