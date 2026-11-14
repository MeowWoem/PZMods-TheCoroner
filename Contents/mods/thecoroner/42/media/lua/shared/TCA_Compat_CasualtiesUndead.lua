require "TCA_Wounds";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.CasualtiesUndead = TCA.Compat.CasualtiesUndead or {};

local X = TCA.Compat.CasualtiesUndead;

X.MOD_ID = "CasualtiesUndead";
X.KEY_OVERDOSE = "TCA_OverdoseAt";
X.OVERDOSE_WINDOW = 2;
X.BLOOD_LOSS_SIGNS = 0.35;

X.LIMBS = {
    { id = "arm_L", root = "Torso_Upper", parts = { "Hand_L", "ForeArm_L", "UpperArm_L" } },
    { id = "arm_R", root = "Torso_Upper", parts = { "Hand_R", "ForeArm_R", "UpperArm_R" } },
    { id = "leg_L", root = "Groin", parts = { "Foot_L", "LowerLeg_L", "UpperLeg_L" } },
    { id = "leg_R", root = "Groin", parts = { "Foot_R", "LowerLeg_R", "UpperLeg_R" } },
};

X.LIMB_PARTS = { "Hand_L", "ForeArm_L", "UpperArm_L", "Hand_R", "ForeArm_R", "UpperArm_R", "Foot_L", "LowerLeg_L", "UpperLeg_L", "Foot_R", "LowerLeg_R", "UpperLeg_R" };
X.ARM_PARTS = { "ForeArm_L", "ForeArm_R" };

X.CONDITION_PARTS = {
    rib_fracture = { part = "Torso_Upper", kind = "ribFracture" },
    pneumothorax = { part = "Torso_Upper", kind = "pneumothorax" },
    concussion = { part = "Head", kind = "concussion" },
    intracranial_bleed = { part = "Head", kind = "intracranialBleed" },
    haemorrhagic_shock = { part = "Torso_Upper", kind = "exsanguination" },
    sepsis = { part = "Torso_Upper", kind = "sepsis" },
    septic_shock = { part = "Torso_Upper", kind = "sepsis" },
    hypothermia = { part = "Torso_Upper", kind = "hypothermiaSigns" },
    hyperthermia = { part = "Torso_Upper", kind = "hyperthermiaSigns" },
    acute_kidney_injury = { part = "Torso_Lower", kind = "organFailureSigns" },
    pulmonary_embolism = { part = "Torso_Upper", kind = "organFailureSigns" },
    pulmonary_oedema = { part = "Torso_Upper", kind = "organFailureSigns" },
    pneumonia = { part = "Torso_Upper", kind = "organFailureSigns" },
    aspiration = { part = "Torso_Upper", kind = "organFailureSigns" },
    dehydration = { part = "Torso_Lower", kind = "organFailureSigns" },
    hypoglycaemia = { part = "Torso_Lower", kind = "organFailureSigns" },
};

X.DEATH_CONDITIONS = {
    { conditions = { "haemorrhagic_shock" }, cause = "hemorrhage" },
    { conditions = { "septic_shock", "sepsis" }, cause = "sepsis" },
    { conditions = { "hypothermia", "hyperthermia" }, cause = "exposure" },
    { conditions = { "acute_kidney_injury", "pulmonary_embolism", "pulmonary_oedema", "pneumonia", "aspiration", "dehydration", "hypoglycaemia" }, cause = "organFailure" },
};

X.ORGAN_MAP = {
    heart = { "heart" },
    lungs = { "lung_l", "lung_r" },
    liver = { "liver" },
    kidneys = { "kidney_l", "kidney_r" },
    gut = { "stomach", "intestines" },
};
X.PATHOLOGY_STEPS = { 15, 40, 70 };

X.KINDS = {
    "amputationOpen", "amputationSealed", "amputationHealed", "prosthetic", "limbMissing",
    "eyeMissingL", "eyeMissingR", "ribFracture", "pneumothorax", "concussion", "intracranialBleed",
    "necrotic", "woundInfection", "pressureInjury", "compartmentSyndrome", "tourniquet",
    "sepsis", "exsanguination", "hypothermiaSigns", "hyperthermiaSigns", "organFailureSigns",
    "overdoseSigns", "injectionMarks",
};

X.MIN_LEVEL = {
    ribFracture = 3, pressureInjury = 3, woundInfection = 3, necrotic = 3,
    exsanguination = 3, hypothermiaSigns = 3, hyperthermiaSigns = 3,
    compartmentSyndrome = 6, pneumothorax = 6, intracranialBleed = 6, concussion = 6,
    organFailureSigns = 6, overdoseSigns = 6, sepsis = 6,
};

X.DETECT = {
    limbMissing = 1, amputationOpen = 1, amputationSealed = 1, amputationHealed = 1, prosthetic = 1, tourniquet = 1,
    eyeMissingL = 0.95, eyeMissingR = 0.95, pressureInjury = 0.6, woundInfection = 0.6, necrotic = 0.6, exsanguination = 0.6,
    ribFracture = 0.5, hypothermiaSigns = 0.5, hyperthermiaSigns = 0.5, injectionMarks = 0.4,
    compartmentSyndrome = 0.4, organFailureSigns = 0.4, overdoseSigns = 0.4, sepsis = 0.35,
    pneumothorax = 0.3, intracranialBleed = 0.3, concussion = 0.3,
};

X.CONFUSE = {
    amputationSealed = "amputationHealed", amputationHealed = "amputationSealed",
    pneumothorax = "ribFracture", hyperthermiaSigns = "hypothermiaSigns",
};

X.CAUSES = { "hemorrhage", "sepsis", "exposure", "overdose", "organFailure" };

X.NATURAL_CAUSES = {
    { cause = "hemorrhage", weight = 6 },
    { cause = "sepsis", weight = 6 },
    { cause = "exposure", weight = 6 },
    { cause = "overdose", weight = 5 },
    { cause = "organFailure", weight = 5 },
};

X.LETHAL_WOUNDS = {
    { kind = "exsanguination", cause = "hemorrhage" },
    { kind = "sepsis", cause = "sepsis" },
    { kind = "overdoseSigns", cause = "overdose" },
    { kind = "hypothermiaSigns", cause = "exposure" },
    { kind = "hyperthermiaSigns", cause = "exposure" },
    { kind = "organFailureSigns", cause = "organFailure" },
};

X.OLD_FINDINGS = {
    { kind = "ribFracture", weight = 30, part = "Torso_Upper" },
    { kind = "injectionMarks", weight = 12, part = "ForeArm_L" },
    { kind = "eyeMissingL", weight = 8, part = "Head" },
    { kind = "eyeMissingR", weight = 8, part = "Head" },
};
X.OLD_FINDING_CHANCE = 30;

function X.isActive()
    if not TCA.Wounds.isModActivated(X.MOD_ID) then
        return false;
    end
    return CasualtiesUndead ~= nil and type(CasualtiesUndead.Config) == "table";
end

function X.getTable(md, key)
    local value = md[key];
    if type(value) ~= "table" then
        return nil;
    end
    return value;
end

function X.add(list, part, kind)
    TCA.Wounds.addKind(list, part, kind);
end

function X.stumpKind(entry)
    if entry.healed then
        return "amputationHealed";
    end
    if entry.sealed then
        return "amputationSealed";
    end
    return "amputationOpen";
end

function X.snapshotLimbs(md, list)
    local limbs = X.getTable(md, "CU_Limbs");
    if not limbs then
        return;
    end
    for i = 1, #X.LIMBS do
        local limb = X.LIMBS[i];
        local entry = limbs[limb.id];
        local level = 0;
        if type(entry) == "table" then
            level = math.floor(tonumber(entry.level) or 0);
        end
        if level > 0 then
            level = math.min(level, #limb.parts);
            for j = 1, level do
                X.add(list, limb.parts[j], "limbMissing");
            end
            local stump = limb.parts[level + 1] or limb.root;
            X.add(list, stump, X.stumpKind(entry));
            if entry.prosthetic then
                X.add(list, stump, "prosthetic");
            end
        end
    end
end

function X.snapshotOpenStumps(md, list, kind)
    local limbs = X.getTable(md, "CU_Limbs");
    if not limbs then
        return;
    end
    for i = 1, #X.LIMBS do
        local limb = X.LIMBS[i];
        local entry = limbs[limb.id];
        if type(entry) == "table" and (tonumber(entry.level) or 0) > 0 and not entry.sealed then
            local level = math.min(math.floor(tonumber(entry.level)), #limb.parts);
            X.add(list, limb.parts[level + 1] or limb.root, kind);
        end
    end
end

function X.snapshotEyes(md, list)
    local harm = X.getTable(md, "CU_Harm");
    if not harm then
        return;
    end
    if harm.eyeL then
        X.add(list, "Head", "eyeMissingL");
    end
    if harm.eyeR then
        X.add(list, "Head", "eyeMissingR");
    end
end

function X.snapshotTourniquets(md, list, withInjury)
    local tourniquets = X.getTable(md, "CU_Tourniquets");
    if not tourniquets then
        return;
    end
    for part, _ in pairs(tourniquets) do
        if type(part) == "string" then
            X.add(list, part, "tourniquet");
            if withInjury then
                X.add(list, part, "pressureInjury");
            end
        end
    end
end

function X.snapshotPartsWhere(player, list, kind, test)
    local bodyDamage = player:getBodyDamage();
    if not bodyDamage then
        return;
    end
    for i = 1, #X.LIMB_PARTS do
        local part = bodyDamage:getBodyPart(BodyPartType.FromString(X.LIMB_PARTS[i]));
        if part and test(part) then
            X.add(list, X.LIMB_PARTS[i], kind);
        end
    end
end

function X.isInfectedPart(part)
    return part:isInfectedWound();
end

function X.isFracturedPart(part)
    return part:getFractureTime() > 0;
end

function X.snapshotConditions(player, md, list)
    local conditions = X.getTable(md, "CU_Cond") or {};
    for id, _ in pairs(conditions) do
        local mapped = X.CONDITION_PARTS[id];
        if mapped then
            X.add(list, mapped.part, mapped.kind);
        end
    end
    if conditions.necrosis then
        X.snapshotOpenStumps(md, list, "necrotic");
    end
    if conditions.wound_infection then
        X.snapshotPartsWhere(player, list, "woundInfection", X.isInfectedPart);
    end
    if conditions.compartment_syndrome then
        X.snapshotPartsWhere(player, list, "compartmentSyndrome", X.isFracturedPart);
    end
    X.snapshotTourniquets(md, list, conditions.pressure_injury ~= nil);
    if (tonumber(md.CU_BloodLost) or 0) >= X.BLOOD_LOSS_SIGNS then
        X.add(list, "Torso_Upper", "exsanguination");
    end
end

function X.isRecentOverdose(md)
    local at = tonumber(md[X.KEY_OVERDOSE]);
    return at ~= nil and getGameTime():getWorldAgeHours() - at <= X.OVERDOSE_WINDOW;
end

function X.snapshotDrugs(md, list)
    if md.CU_Drug ~= nil then
        X.add(list, "ForeArm_L", "injectionMarks");
    end
    if X.isRecentOverdose(md) then
        X.add(list, "Head", "overdoseSigns");
    end
end

function X.snapshot(player, list)
    local md = player:getModData();
    X.snapshotLimbs(md, list);
    X.snapshotEyes(md, list);
    X.snapshotConditions(player, md, list);
    X.snapshotDrugs(md, list);
end

function X.hasAnyCondition(conditions, ids)
    for i = 1, #ids do
        if conditions[ids[i]] ~= nil then
            return true;
        end
    end
    return false;
end

function X.deathCause(character)
    local md = character:getModData();
    if X.isRecentOverdose(md) then
        return "overdose";
    end
    local conditions = X.getTable(md, "CU_Cond") or {};
    for i = 1, #X.DEATH_CONDITIONS do
        local entry = X.DEATH_CONDITIONS[i];
        if X.hasAnyCondition(conditions, entry.conditions) then
            return entry.cause;
        end
    end
    if (tonumber(md.CU_BloodLost) or 0) >= X.BLOOD_LOSS_SIGNS then
        return "hemorrhage";
    end
    return nil;
end

function X.pathologyLevel(damage)
    local level = 0;
    for i = 1, #X.PATHOLOGY_STEPS do
        if damage >= X.PATHOLOGY_STEPS[i] then
            level = i;
        end
    end
    return level;
end

function X.organPathology(player)
    local organs = X.getTable(player:getModData(), "CU_Organs");
    if not organs then
        return nil;
    end
    local result = {};
    for id, targets in pairs(X.ORGAN_MAP) do
        local level = X.pathologyLevel(tonumber(organs[id]) or 0);
        if level > 0 then
            for i = 1, #targets do
                result[targets[i]] = level;
            end
        end
    end
    return result;
end

function X.pick(list)
    return list[ZombRand(#list) + 1];
end

function X.chance(percent)
    return ZombRand(100) < percent;
end

function X.inventOld(list)
    if not X.chance(X.OLD_FINDING_CHANCE) then
        return;
    end
    local finding = TCA.Wounds.pickWeighted(X.OLD_FINDINGS);
    X.add(list, finding.part, finding.kind);
end

function X.inventTrauma(list)
    if X.chance(40) then
        X.add(list, "Torso_Upper", "ribFracture");
    end
    if X.chance(30) then
        X.add(list, "Head", "intracranialBleed");
    end
end

function X.inventHemorrhage(list)
    local part = X.pick(X.LIMB_PARTS);
    X.add(list, part, "laceration");
    X.add(list, "Torso_Upper", "exsanguination");
    if X.chance(30) then
        X.add(list, part, "tourniquet");
    end
end

function X.inventSepsis(list)
    X.add(list, X.pick(X.LIMB_PARTS), "woundInfection");
    X.add(list, "Torso_Upper", "sepsis");
end

function X.inventExposure(list)
    if X.chance(75) then
        X.add(list, "Torso_Upper", "hypothermiaSigns");
    else
        X.add(list, "Torso_Upper", "hyperthermiaSigns");
    end
end

function X.inventOverdose(list)
    X.add(list, X.pick(X.ARM_PARTS), "injectionMarks");
    X.add(list, "Head", "overdoseSigns");
end

function X.inventOrganFailure(list)
    X.add(list, "Torso_Lower", "organFailureSigns");
end

function X.invent(list, cause)
    X.inventOld(list);
    if cause == "blunt" or cause == "fall" then
        X.inventTrauma(list);
    elseif cause == "hemorrhage" then
        X.inventHemorrhage(list);
    elseif cause == "sepsis" then
        X.inventSepsis(list);
    elseif cause == "exposure" then
        X.inventExposure(list);
    elseif cause == "overdose" then
        X.inventOverdose(list);
    elseif cause == "organFailure" then
        X.inventOrganFailure(list);
    end
end

function X.onOverdoseStage(player, drugId, stage, sev)
    if player and tonumber(stage) and tonumber(stage) >= 1 then
        player:getModData()[X.KEY_OVERDOSE] = getGameTime():getWorldAgeHours();
    end
    return X.originalApplyStage(player, drugId, stage, sev);
end

function X.patchDrugs()
    if not X.isActive() then
        return;
    end
    local drugs = CasualtiesUndead.Drugs;
    if type(drugs) ~= "table" or type(drugs.applyStage) ~= "function" then
        return;
    end
    if type(drugs.TCA_OriginalApplyStage) ~= "function" then
        drugs.TCA_OriginalApplyStage = drugs.applyStage;
    end
    X.originalApplyStage = drugs.TCA_OriginalApplyStage;
    drugs.applyStage = X.onOverdoseStage;
end

TCA.Wounds.registerProvider({
    id = X.MOD_ID,
    isActive = X.isActive,
    kinds = X.KINDS,
    minLevel = X.MIN_LEVEL,
    detect = X.DETECT,
    confuse = X.CONFUSE,
    causes = X.CAUSES,
    naturalCauses = X.NATURAL_CAUSES,
    lethal = X.LETHAL_WOUNDS,
    snapshot = X.snapshot,
    deathCause = X.deathCause,
    invent = X.invent,
    organPathology = X.organPathology,
});

Events.OnGameBoot.Add(X.patchDrugs);
Events.OnGameStart.Add(X.patchDrugs);
if Events.OnServerStarted then
    Events.OnServerStarted.Add(X.patchDrugs);
end
