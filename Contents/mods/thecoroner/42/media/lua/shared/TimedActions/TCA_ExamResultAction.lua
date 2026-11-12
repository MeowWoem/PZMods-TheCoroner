require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_Exam";

TCA_ExamResultAction = ISBaseTimedAction:derive("TCA_ExamResultAction");

function TCA_ExamResultAction:isValid()
    return true;
end

function TCA_ExamResultAction:perform()
    ISBaseTimedAction.perform(self);
end

function TCA_ExamResultAction:complete()
    local E = TCA.Exam;
    local body = TCA.findBodyAt(self.bx, self.by, self.bz);
    if not body then
        return true;
    end
    local key = E.getObserverKey(self.character, self.observer);
    if E.getResult(body, key) then
        return true;
    end
    if E.isRangeTooWide(self.minHours, self.maxHours) then
        E.notifyResult(self.character, false, 0, true);
        return true;
    end
    local ok, xp, lo, hi = E.score(body, self.minHours, self.maxHours);
    E.storeResult(body, key, lo, hi, ok);
    body:transmitModData();
    if xp > 0 then
        addXp(self.character, Perks.Doctor, xp);
    end
    E.notifyResult(self.character, ok, xp);
    return true;
end

function TCA_ExamResultAction:getDuration()
    return 1;
end

function TCA_ExamResultAction:new(character, bx, by, bz, minHours, maxHours, observer)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.observer = observer;
    o.bx = bx;
    o.by = by;
    o.bz = bz;
    o.minHours = minHours;
    o.maxHours = maxHours;
    o.maxTime = o:getDuration();
    o.stopOnWalk = false;
    o.stopOnRun = false;
    return o;
end
