--***********************************************************
--**  Action : enregistrer le resultat du mini-jeu         **
--**  - sauvegarde la progression sur le cadavre ;         **
--**  - donne l'XP uniquement pour ce qui est nouveau      **
--**    (pas de farm en arretant / reprenant).             **
--**  Etapes : incision -> peau ecartee -> cotes coupees.  **
--**  Partagee : complete() tourne sur le serveur en multi.**
--**  Les coupures, elles, sont appliquees immediatement   **
--**  pendant le mini-jeu (voir TCA_Client.requestCut).    **
--***********************************************************

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

-- Incision : renvoie l'XP gagnee (0 si rien de nouveau).
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
        -- Rien de nouveau : on ne recule jamais et on ne paie pas deux fois.
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
    local paths = tostring(self.paths or "");
    if string.len(paths) <= A.MAX_PATH_LENGTH then
        md["TCA_A_paths"] = paths;
    end
    return (A.XP_MIN + (A.XP_MAX - A.XP_MIN) * accuracy) * delta;
end

-- Peau ecartee a la pince.
function TCA_AutopsyResultAction:applyOpen(body)
    local A = TCA.Autopsy;
    if not self.opened then
        return 0;
    end
    if not A.isIncisionDone(body) or A.getStep(body) >= A.STEP_OPENED then
        return 0;
    end
    if not A.findForceps(self.character) then
        return 0;
    end
    body:getModData()["TCA_A_step"] = A.STEP_OPENED;
    return A.XP_OPEN;
end

-- Cotes coupees (fusion avec ce qui etait deja coupe).
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
    if A.countRibs(stored) >= #A.RIBS then
        md["TCA_A_step"] = A.STEP_CHEST;
    end
    return A.XP_PER_RIB * added;
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

    -- Dans l'ordre : chaque etape s'appuie sur la precedente.
    local xp = 0;
    xp = xp + self:applyIncision(body);
    xp = xp + self:applyOpen(body);
    xp = xp + self:applyRibs(body);
    if xp <= 0 then
        return true;
    end

    body:transmitModData();
    addXp(self.character, Perks.Doctor, xp);
    A.notifyXp(self.character, xp);
    return true;
end

function TCA_AutopsyResultAction:getDuration()
    return 1;
end

-- Les noms des parametres doivent correspondre aux champs de "o".
function TCA_AutopsyResultAction:new(character, tableObject, segIndex, segProgress, accuracy, paths, opened, ribs)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.segIndex = segIndex;
    o.segProgress = segProgress;
    o.accuracy = accuracy;
    o.paths = paths;
    o.opened = opened;
    o.ribs = ribs;
    o.maxTime = o:getDuration();
    o.stopOnWalk = false;
    o.stopOnRun = false;
    return o;
end
