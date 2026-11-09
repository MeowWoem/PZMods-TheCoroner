require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_Autopsy";

TCA_AutopsyResultAction = ISBaseTimedAction:derive("TCA_AutopsyResultAction");

function TCA_AutopsyResultAction:isValid()
    return self.tableObject ~= nil and self.tableObject:getSquare() ~= nil;
end

function TCA_AutopsyResultAction:perform()
    ISBaseTimedAction.perform(self);
end

local function clamp(v, lo, hi)
    v = tonumber(v) or 0;
    if v < lo then
        return lo;
    end
    if v > hi then
        return hi;
    end
    return v;
end

function TCA_AutopsyResultAction:applyIncision(body)
    local A = TCA.Autopsy;
    local md = body:getModData();
    if md["TCA_Autopsied"] then
        return 0;
    end
    if not A.findScalpel(self.character) then
        return 0;
    end

    local count = #A.INCISION_Y;
    local segIndex = math.floor(clamp(self.segIndex, 1, count + 1));
    local segProgress = clamp(self.segProgress, 0, 1);
    local accuracy = clamp(self.accuracy, 0, 1);

    local stored = A.getState(body);
    local oldFraction = A.getFraction(stored.segIndex, stored.segProgress);
    local newFraction = A.getFraction(segIndex, segProgress);
    local delta = newFraction - oldFraction;
    if delta <= 0 then
        return 0;
    end

    if newFraction >= 0.999 then
        md["TCA_Autopsied"] = true;
        md["TCA_A_seg"] = count + 1;
        md["TCA_A_prog"] = 0;
    else
        md["TCA_A_seg"] = segIndex;
        md["TCA_A_prog"] = segProgress;
    end
    md["TCA_A_acc"] = accuracy;
    md["TCA_A_accN"] = math.floor(clamp(self.accSamples, 0, 10000000));
    local paths = tostring(self.paths or "");
    if string.len(paths) <= A.MAX_PATH_LENGTH then
        md["TCA_A_paths"] = paths;
    end
    return (A.XP_MIN + (A.XP_MAX - A.XP_MIN) * accuracy) * delta;
end

function TCA_AutopsyResultAction:applyOpen(body)
    local A = TCA.Autopsy;
    if not A.isIncisionDone(body) or A.getStep(body) >= A.STEP_OPENED then
        return 0;
    end
    if not A.findForceps(self.character) then
        return 0;
    end
    local stored = A.getOpenState(body);
    local left = clamp(self.openL, 0, 1);
    local right = clamp(self.openR, 0, 1);
    local tears = math.floor(clamp(self.tears, 0, 100000));
    if tears < stored.tears then
        tears = stored.tears;
    end
    if left == stored.left and right == stored.right and tears == stored.tears then
        return 0;
    end
    local md = body:getModData();
    md["TCA_A_openL"] = left;
    md["TCA_A_openR"] = right;
    md["TCA_A_tears"] = tears;
    self.changed = true;
    if left >= A.OPEN_DONE and right >= A.OPEN_DONE then
        md["TCA_A_step"] = A.STEP_OPENED;
        return A.XP_OPEN;
    end
    return 0;
end

function TCA_AutopsyResultAction:applyRibs(body)
    local A = TCA.Autopsy;
    if A.getStep(body) ~= A.STEP_OPENED then
        return 0;
    end
    if not A.findRibTool(self.character) then
        return 0;
    end
    local stored = A.getRibs(body);
    local sent = A.decodeRibs(tostring(self.ribs or ""));
    local added = 0;
    for i = 1, #A.RIBS do
        if sent[i] and not stored[i] then
            stored[i] = true;
            added = added + 1;
        end
    end
    if added == 0 then
        return 0;
    end
    local md = body:getModData();
    md["TCA_A_ribs"] = A.encodeRibs(stored);
    return A.XP_PER_RIB * added;
end

function TCA_AutopsyResultAction:applyPlastron(body)
    local A = TCA.Autopsy;
    if not self.plastron or A.getStep(body) ~= A.STEP_OPENED then
        return 0;
    end
    if A.countRibs(A.getRibs(body)) < #A.RIBS then
        return 0;
    end
    body:getModData()["TCA_A_step"] = A.STEP_CHEST;
    self.changed = true;
    return A.XP_PLASTRON;
end

function TCA_AutopsyResultAction:applyOrgans(body)
    local A = TCA.Autopsy;
    if A.getStep(body) < A.STEP_CHEST then
        return 0;
    end
    local stored = A.getOrganState(body);
    local done = math.floor(clamp(self.organs, 0, #TCA.Organs.LIST));
    local damage = math.floor(clamp(self.organDamage, 0, 100000));
    if damage < stored.damage then
        damage = stored.damage;
    end
    local xp = 0;
    local md = body:getModData();
    if done > stored.done and A.findScalpel(self.character) then
        md["TCA_A_organs"] = done;
        xp = A.XP_PER_ORGAN * (done - stored.done);
        self.changed = true;
    end
    if damage > stored.damage then
        md["TCA_A_odmg"] = damage;
        self.changed = true;
    end
    return xp;
end

function TCA_AutopsyResultAction:complete()
    local A = TCA.Autopsy;
    local body = TCA.findBodyOnTable(self.tableObject);
    if not body then
        return true;
    end
    if A.getBlockingClothing(body) then
        return true;
    end

    self.changed = false;
    local xp = 0;
    xp = xp + self:applyIncision(body);
    xp = xp + self:applyOpen(body);
    xp = xp + self:applyRibs(body);
    xp = xp + self:applyPlastron(body);
    xp = xp + self:applyOrgans(body);
    if xp <= 0 and not self.changed then
        return true;
    end

    body:transmitModData();
    if xp > 0 then
        addXp(self.character, Perks.Doctor, xp);
        A.notifyXp(self.character, xp);
    end
    return true;
end

function TCA_AutopsyResultAction:getDuration()
    return 1;
end

function TCA_AutopsyResultAction:new(character, tableObject, segIndex, segProgress, accuracy, paths, openL, openR, tears, ribs, accSamples, organs, organDamage, plastron)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.segIndex = segIndex;
    o.segProgress = segProgress;
    o.accuracy = accuracy;
    o.paths = paths;
    o.openL = openL;
    o.openR = openR;
    o.tears = tears;
    o.ribs = ribs;
    o.accSamples = accSamples;
    o.organs = organs;
    o.organDamage = organDamage;
    o.plastron = plastron;
    o.maxTime = o:getDuration();
    o.stopOnWalk = false;
    o.stopOnRun = false;
    return o;
end
