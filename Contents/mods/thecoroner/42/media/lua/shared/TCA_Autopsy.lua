--***********************************************************
--**  The Coroner : donnees de l'autopsie                  **
--**  Partagees client / serveur (trace, progression,      **
--**  sauvegarde sur le cadavre, coupures, XP).            **
--***********************************************************

require "TCA_Shared";

TCA.Autopsy = TCA.Autopsy or {};
local A = TCA.Autopsy;

-- Reglages de la recompense
A.XP_MIN = 10;            -- XP pour une incision complete baclee
A.XP_MAX = 50;            -- XP pour une incision complete parfaite
A.INFECTION_CHANCE = 30;  -- % d'infection de plaie par coupure sans gants
A.MAX_PATH_LENGTH = 20000; -- taille max de la chaine de traces sauvegardee

-- BD_Health | BD_bandaged | BD_bleeding | BD_stitched | BD_woundInfectionLevel
-- | BD_infectedWound | BD_bleedingTime | BD_cut | BD_cutTime
A.SYNC_FLAGS = 0xc00003808b;

-- Recompenses des etapes suivantes
A.XP_OPEN = 5;            -- XP pour ecarter la peau
A.XP_PER_RIB = 1.5;       -- XP par cote coupee (12 cotes = 18 XP)

-- Incision en Y, en coordonnees "corps" (origine : pixel (130, 20) de la texture).
-- Points releves sur le contour des calques torso_stepN.png (x2) :
-- coins superieurs de l'ouverture -> creux central, puis -> pointe basse.
A.INCISION_Y = {
    { ax = -37.5, ay = 96, bx = 0, by = 107.5 },
    { ax = 37.5, ay = 96, bx = 0, by = 107.5 },
    { ax = 0, ay = 107.5, bx = 0, by = 225 },
};

-- Etapes apres l'incision (modData "TCA_A_step").
A.STEP_CLOSED = 0;  -- peau encore fermee
A.STEP_OPENED = 1;  -- peau ecartee (lambeaux rabattus)
A.STEP_CHEST = 2;   -- cotes coupees, plastron retire
A.LAST_STEP = A.STEP_CHEST;

-- Reperes de coupe des cotes (coordonnees corps), le long des jonctions
-- costo-cartilagineuses, releves sur torso_step1.png.
A.RIBS = {
    { x = -21, y = 114 },
    { x = -22, y = 123 },
    { x = -23.5, y = 132 },
    { x = -25, y = 141 },
    { x = -26.5, y = 150 },
    { x = -28, y = 159 },
    { x = 21, y = 114 },
    { x = 22, y = 123 },
    { x = 23.5, y = 132 },
    { x = 25, y = 141 },
    { x = 26.5, y = 150 },
    { x = 28, y = 159 },
};

-- Outils : pince pour ecarter la peau (par type d'objet)...
A.FORCEPS_TYPES = { "SutureNeedleHolder", "Forceps_Forged", "Tweezers" };

-- ... et coupe-boulon (prioritaire) ou scie pour les cotes (par tag).
-- Un tag absent de la version du jeu vaut nil et est ignore.
A.RIB_TOOLS = {
    { tag = ItemTag.BOLT_CUTTERS, mode = "cutter" },
    { tag = ItemTag.SAW, mode = "saw" },
    { tag = ItemTag.SMALL_SAW, mode = "saw" },
    { tag = ItemTag.METAL_SAW, mode = "saw" },
    { tag = ItemTag.CRUDE_SAW, mode = "saw" },
};

local function segLength(seg)
    local dx = seg.bx - seg.ax;
    local dy = seg.by - seg.ay;
    return math.sqrt(dx * dx + dy * dy);
end

A.TOTAL_LENGTH = 0;
for _, seg in ipairs(A.INCISION_Y) do
    seg.length = segLength(seg);
    A.TOTAL_LENGTH = A.TOTAL_LENGTH + seg.length;
end

-- Fraction (0..1) de l'incision faite pour un segment courant et sa progression.
function A.getFraction(segIndex, segProgress)
    local count = #A.INCISION_Y;
    if segIndex > count then
        return 1;
    end
    local done = 0;
    for i, seg in ipairs(A.INCISION_Y) do
        if i < segIndex then
            done = done + seg.length;
        elseif i == segIndex then
            done = done + seg.length * segProgress;
        end
    end
    return done / A.TOTAL_LENGTH;
end

--------------------------------------------------------------
-- Etat sauvegarde sur le cadavre (modData)
--------------------------------------------------------------

function A.getState(body)
    local md = body:getModData();
    local state = {};
    state.segIndex = tonumber(md["TCA_A_seg"]) or 1;
    state.segProgress = tonumber(md["TCA_A_prog"]) or 0;
    state.paths = md["TCA_A_paths"] or "";
    if md["TCA_Autopsied"] then
        state.segIndex = #A.INCISION_Y + 1;
        state.segProgress = 0;
    end
    return state;
end

-- Traces : "x,y;x,y|x,y;...|..." (un bloc par segment), coordonnees corps.
function A.encodePaths(paths)
    local blocks = {};
    for i = 1, #A.INCISION_Y do
        local pts = {};
        local path = paths[i] or {};
        for _, pt in ipairs(path) do
            table.insert(pts, string.format("%.1f,%.1f", pt.x, pt.y));
        end
        table.insert(blocks, table.concat(pts, ";"));
    end
    return table.concat(blocks, "|");
end

function A.decodePaths(str)
    local paths = {};
    for i = 1, #A.INCISION_Y do
        paths[i] = {};
    end
    if not str or str == "" then
        return paths;
    end
    local index = 1;
    for block in string.gmatch(str .. "|", "([^|]*)|") do
        if index > #A.INCISION_Y then
            break;
        end
        for xs, ys in string.gmatch(block, "([%-%d%.]+),([%-%d%.]+)") do
            table.insert(paths[index], { x = tonumber(xs), y = tonumber(ys) });
        end
        index = index + 1;
    end
    return paths;
end

--------------------------------------------------------------
-- Etapes suivantes : ouverture de la peau, cotes
--------------------------------------------------------------

function A.isIncisionDone(body)
    return body:getModData()["TCA_Autopsied"] and true or false;
end

function A.getStep(body)
    return tonumber(body:getModData()["TCA_A_step"]) or A.STEP_CLOSED;
end

-- Prochaine chose a faire : "incision", "open", "ribs" ou "done".
function A.getStage(body)
    if not A.isIncisionDone(body) then
        return "incision";
    end
    local step = A.getStep(body);
    if step < A.STEP_OPENED then
        return "open";
    end
    if step < A.STEP_CHEST then
        return "ribs";
    end
    return "done";
end

-- Cotes coupees : chaine "0"/"1", un caractere par repere de A.RIBS.
function A.decodeRibs(str)
    local ribs = {};
    str = str or "";
    for i = 1, #A.RIBS do
        ribs[i] = string.sub(str, i, i) == "1";
    end
    return ribs;
end

function A.encodeRibs(ribs)
    local chars = {};
    for i = 1, #A.RIBS do
        if ribs[i] then
            chars[i] = "1";
        else
            chars[i] = "0";
        end
    end
    return table.concat(chars);
end

function A.countRibs(ribs)
    local count = 0;
    for i = 1, #A.RIBS do
        if ribs[i] then
            count = count + 1;
        end
    end
    return count;
end

function A.getRibs(body)
    return A.decodeRibs(body:getModData()["TCA_A_ribs"]);
end

--------------------------------------------------------------
-- Outils
--------------------------------------------------------------

local function isNotBroken(item)
    return not item:isBroken();
end

function A.findScalpel(character)
    return character:getInventory():getFirstTypeRecurse("Scalpel");
end

function A.findForceps(character)
    local inv = character:getInventory();
    for _, itemType in ipairs(A.FORCEPS_TYPES) do
        local item = inv:getFirstTypeRecurse(itemType);
        if item and not item:isBroken() then
            return item;
        end
    end
    return nil;
end

-- Renvoie l'outil et son mode ("cutter" ou "saw"), ou nil.
function A.findRibTool(character)
    local inv = character:getInventory();
    for _, def in ipairs(A.RIB_TOOLS) do
        if def.tag then
            local item = inv:getFirstTagEvalRecurse(def.tag, isNotBroken);
            if item then
                return item, def.mode;
            end
        end
    end
    return nil, nil;
end

function A.hasToolForStage(character, stage)
    if stage == "incision" then
        return A.findScalpel(character) ~= nil;
    elseif stage == "open" then
        return A.findForceps(character) ~= nil;
    elseif stage == "ribs" then
        return A.findRibTool(character) ~= nil;
    end
    return false;
end

--------------------------------------------------------------
-- Coupure a la main (appliquee la ou le personnage fait autorite :
-- serveur en multijoueur, local en solo)
--------------------------------------------------------------

function A.applyCut(character)
    local partType = BodyPartType.Hand_L;
    if ZombRand(4) == 0 then
        partType = BodyPartType.Hand_R;
    end
    local bodyPart = character:getBodyDamage():getBodyPart(partType);
    -- forceNoInfection = true : pas de Knox, seulement une coupure.
    bodyPart:setCut(true, true);
    if not character:getClothingItem_Hands() and ZombRand(100) < A.INFECTION_CHANCE then
        bodyPart:setInfectedWound(true);
    end
    syncBodyPart(bodyPart, A.SYNC_FLAGS);
end

--------------------------------------------------------------
-- Affichage de l'XP gagnee au-dessus du personnage
--------------------------------------------------------------

function A.showXpHalo(character, xp)
    local rounded = math.floor(xp * 10 + 0.5) / 10;
    if rounded <= 0 then
        return;
    end
    HaloTextHelper.addGoodText(character, getText("IGUI_TCA_XpGain", tostring(rounded), PerkFactory.getPerkName(Perks.Doctor)));
end

function A.notifyXp(character, xp)
    if isServer() then
        local args = {};
        args.xp = xp;
        sendServerCommand(character, "TCA", "xp", args);
    else
        A.showXpHalo(character, xp);
    end
end

--------------------------------------------------------------
-- Debug : remettre un cadavre a zero (autopsie non commencee)
--------------------------------------------------------------

function A.resetBody(body)
    local md = body:getModData();
    md["TCA_A_seg"] = nil;
    md["TCA_A_prog"] = nil;
    md["TCA_A_paths"] = nil;
    md["TCA_Autopsied"] = nil;
    md["TCA_A_step"] = nil;
    md["TCA_A_ribs"] = nil;
    body:transmitModData();
end

--------------------------------------------------------------
-- Le cadavre doit etre deshabille au niveau du torse
-- (le slip fait partie de la peau des zombies : il ne compte pas).
--------------------------------------------------------------

-- Parties du corps sur lesquelles passe l'incision en Y.
A.INCISION_PARTS = { "Torso_Upper", "Torso_Lower" };

-- Renvoie le premier vetement porte qui couvre le torse, ou nil.
function A.getBlockingClothing(body)
    local worn = body:getWornItems();
    if not worn then
        return nil;
    end
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i);
        if item and instanceof(item, "Clothing") then
            local parts = BloodClothingType.getCoveredParts(item:getBloodClothingType());
            if parts then
                for j = 0, parts:size() - 1 do
                    local partName = tostring(parts:get(j));
                    for _, wanted in ipairs(A.INCISION_PARTS) do
                        if partName == wanted then
                            return item;
                        end
                    end
                end
            end
        end
    end
    return nil;
end
