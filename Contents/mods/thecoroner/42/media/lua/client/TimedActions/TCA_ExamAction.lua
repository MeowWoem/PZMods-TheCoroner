require "TimedActions/ISBaseTimedAction";
require "TimedActions/ISTimedActionQueue";
require "TimedActions/TCA_ExamResultAction";
require "TCA_Shared";
require "TCA_Exam";

TCA_ExamAction = ISBaseTimedAction:derive("TCA_ExamAction");

function TCA_ExamAction:getBody()
    return TCA.findBodyAt(self.bx, self.by, self.bz);
end

function TCA_ExamAction:isValid()
    return self:getBody() ~= nil;
end

function TCA_ExamAction:waitToStart()
    self.character:faceLocation(self.bx, self.by);
    return self.character:shouldBeTurning();
end

function TCA_ExamAction:update()
    self.character:faceLocation(self.bx, self.by);
    self.character:setMetabolicTarget(Metabolics.LightWork);
    if self.ui and self.ui.finished then
        self:forceComplete();
    end
end

function TCA_ExamAction:start()
    self:setActionAnim("Loot");
    if self.onTable then
        self:setAnimVariable("LootPosition", "Mid");
    else
        self:setAnimVariable("LootPosition", "Low");
    end
    self.ui = TCA_ExamUI.open(self.character, self:getBody());
end

function TCA_ExamAction:closeUI(insertNow)
    if not self.ui then
        return;
    end
    local result = self.ui:collectResult();
    self.ui:closeSilently();
    self.ui = nil;
    if not result.conclude then
        return;
    end
    local action = TCA_ExamResultAction:new(self.character, self.bx, self.by, self.bz, result.minHours, result.maxHours);
    if insertNow and ISTimedActionQueue.addAfter(self, action) then
        return;
    end
    TCA_Client.queueNextTick(action);
end

function TCA_ExamAction:stop()
    self:closeUI(false);
    ISBaseTimedAction.stop(self);
end

function TCA_ExamAction:perform()
    self:closeUI(true);
    ISBaseTimedAction.perform(self);
end

function TCA_ExamAction:new(character, body)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.bx = body:getX();
    o.by = body:getY();
    o.bz = body:getZ();
    o.onTable = not TCA.isBodyOnFloor(body);
    o.maxTime = -1;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
    return o;
end
