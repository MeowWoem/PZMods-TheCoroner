require "TCA_Shared";
require "TCA_Sandbox";
require "TCA_Wounds";
require "TimedActions/ISEatFoodAction";
require "TimedActions/ISAddItemInRecipe";
require "TCA_OrganFood";
require "TCA_Exam";

TCA = TCA or {};
TCA.Cannibal = TCA.Cannibal or {};

local C = TCA.Cannibal;

C.ORGAN_PREFIX = "TCA.Organ_";
C.HIDDEN = "TCA.HiddenMeat";
C.HIDDEN_INFECTED = "TCA.HiddenMeatInfected";
C.DISH_COOKS = "TCA_HumanCooks";
C.DISH_INFECTED = "TCA_HumanInfected";
C.POISONER_KEY = "addedPoisonBy";
C.EVOLVED_FACTOR = 0.3;
C.KEY = "TCA_Cannibal";

C.STRESS_HIT = 0.25;
C.UNHAPPY_HIT = 25;
C.FIRST_UNHAPPY = 15;
C.FIRST_SICKNESS = 25;
C.GUILT_HOURS = 12;
C.GUILT_FLOOR = 20;
C.HABIT_MIN = 0.25;
C.EXPOSURE_DECAY_PER_DAY = 1;
C.SENSITIVITY_MIN = 0.25;
C.SENSITIVITY_MAX = 2;

C.RELIEF_STRESS = 0.15;
C.RELIEF_UNHAPPY = 10;
C.RELIEF_BOREDOM = 10;
C.CRAVING_START_HOURS = 24;
C.CRAVING_FULL_HOURS = 72;
C.CRAVING_UNHAPPY = 40;
C.CRAVING_BOREDOM = 30;
C.CRAVING_STRESS = 0.3;
C.FLOOR_STEP_UNHAPPY = 2;
C.FLOOR_STEP_BOREDOM = 2;
C.FLOOR_STEP_STRESS = 0.02;

C.SUPPORTED_MODS = { "HarvestZCannibalism", "CZA" };

C.HARVESTZ_PRESETS = {
    SoundPresetOff = { 0, 0 },
    SoundPresetLow = { 1, 1 },
    SoundPresetMed = { 2, 1 },
    SoundPresetHigh = { 3, 2 },
};
C.HARVESTZ_PRESET_ORDER = { "SoundPresetOff", "SoundPresetLow", "SoundPresetMed", "SoundPresetHigh" };

C.CZA_RELIEF = 15;
C.CZA_MORALE = 0.10;
C.CZA_BOREDOM = 0.08;

function C.isHarvestZActive()
    return TCA.Wounds.isModActivated("HarvestZCannibalism") and SandboxVars ~= nil and SandboxVars.Cannibalism ~= nil;
end

function C.getCZATrait()
    if not TCA.Wounds.isModActivated("CZA") then
        return nil;
    end
    if CZA and CZA.CharacterTrait and CZA.CharacterTrait.Cannibal then
        return CZA.CharacterTrait.Cannibal;
    end
    return nil;
end

function C.findSupportedMod()
    if C.isHarvestZActive() then
        return "HarvestZCannibalism";
    end
    if C.getCZATrait() then
        return "CZA";
    end
    return "";
end

function C.getSupportedMod()
    if C.supported == nil then
        C.supported = C.findSupportedMod();
    end
    if C.supported == "" then
        return nil;
    end
    return C.supported;
end

function C.getTrait()
    if TCA.CharacterTrait and TCA.CharacterTrait.Cannibal then
        return TCA.CharacterTrait.Cannibal;
    end
    return nil;
end

function C.hasOwnTrait(character)
    local trait = C.getTrait();
    return trait ~= nil and character:hasTrait(trait);
end

function C.isOrganType(fullType)
    return fullType ~= nil and string.sub(tostring(fullType), 1, string.len(C.ORGAN_PREFIX)) == C.ORGAN_PREFIX;
end

function C.isHiddenType(fullType)
    return fullType == C.HIDDEN or fullType == C.HIDDEN_INFECTED;
end

function C.isHumanFoodType(fullType)
    return C.isOrganType(fullType) or C.isHiddenType(fullType);
end

function C.isCooked(item)
    return item:isCooked() or item:isBurnt();
end

function C.now()
    return getGameTime():getWorldAgeHours();
end

function C.getData(character)
    local md = character:getModData();
    local data = md[C.KEY];
    if type(data) ~= "table" then
        data = {};
        data.meals = 0;
        data.exposure = 0;
        data.last = -1;
        data.guiltUntil = -1;
        data.guiltFloor = 0;
        md[C.KEY] = data;
    end
    return data;
end

function C.getSensitivity(character)
    local s = 1;
    if character:hasTrait(CharacterTrait.HEMOPHOBIC) then
        s = s * 1.5;
    end
    if character:hasTrait(CharacterTrait.COWARDLY) then
        s = s * 1.25;
    end
    if character:hasTrait(CharacterTrait.WEAK_STOMACH) then
        s = s * 1.25;
    end
    if character:hasTrait(CharacterTrait.BRAVE) then
        s = s * 0.75;
    end
    if character:hasTrait(CharacterTrait.IRON_GUT) then
        s = s * 0.75;
    end
    if character:hasTrait(CharacterTrait.DESENSITIZED) then
        s = s * 0.5;
    end
    local desc = character:getDescriptor();
    if desc and (desc:isCharacterProfession(CharacterProfession.DOCTOR) or desc:isCharacterProfession(CharacterProfession.NURSE)) then
        s = s * 0.75;
    end
    return math.max(C.SENSITIVITY_MIN, math.min(C.SENSITIVITY_MAX, s));
end

C.touched = {};

function C.addStat(character, stat, amount)
    local stats = character:getStats();
    if amount >= 0 then
        stats:add(stat, amount);
    else
        stats:remove(stat, -amount);
    end
    C.touched[stat] = true;
end

function C.raiseToFloor(character, stat, floor, step)
    local current = character:getStats():get(stat);
    if current < floor then
        C.addStat(character, stat, math.min(floor - current, step));
    end
end

function C.flushStats(character)
    if isServer() then
        for stat, _ in pairs(C.touched) do
            syncPlayerStats(character, SyncPlayerStatsPacket.getBitMaskForStat(stat));
        end
    end
    C.touched = {};
end

function C.notify(character, key)
    if isServer() then
        local args = {};
        args.key = key;
        sendServerCommand(character, "TCA", "cannibalHalo", args);
        return;
    end
    C.showHalo(character, key);
end

function C.showHalo(character, key)
    if character and HaloTextHelper then
        HaloTextHelper.addBadText(character, getText(key));
    end
end

function C.grantTrait(character, data)
    local trait = C.getTrait();
    if not trait or character:hasTrait(trait) then
        return;
    end
    character:getCharacterTraits():add(trait);
    data.guiltUntil = -1;
    data.guiltFloor = 0;
    if isServer() then
        sendSyncPlayerFields(character, 2);
    end
    C.notify(character, "IGUI_TCA_CannibalTraitGained");
end

function C.applyOwn(character, amount)
    local data = C.getData(character);
    local now = C.now();
    if C.hasOwnTrait(character) then
        C.addStat(character, CharacterStat.STRESS, -C.RELIEF_STRESS * amount);
        C.addStat(character, CharacterStat.UNHAPPINESS, -C.RELIEF_UNHAPPY * amount);
        C.addStat(character, CharacterStat.BOREDOM, -C.RELIEF_BOREDOM * amount);
        data.last = now;
        data.meals = data.meals + amount;
        return;
    end
    local strength = TCA.Sandbox.getCannibalismStrength();
    local threshold = TCA.Sandbox.getCannibalTraitMeals();
    local habit = math.max(C.HABIT_MIN, 1 - data.exposure / math.max(1, threshold));
    local f = C.getSensitivity(character) * strength * habit;
    local hit = math.min(amount, 1.5);
    local first = data.meals <= 0;
    C.addStat(character, CharacterStat.STRESS, C.STRESS_HIT * f * hit);
    local unhappy = C.UNHAPPY_HIT * f * hit;
    if first then
        unhappy = unhappy + C.FIRST_UNHAPPY * f;
        C.addStat(character, CharacterStat.FOOD_SICKNESS, C.FIRST_SICKNESS * f);
    end
    C.addStat(character, CharacterStat.UNHAPPINESS, unhappy);
    data.guiltUntil = math.max(data.guiltUntil, now + C.GUILT_HOURS * f);
    data.guiltFloor = math.max(data.guiltFloor, C.GUILT_FLOOR * f);
    data.exposure = data.exposure + amount;
    data.meals = data.meals + amount;
    data.last = now;
    if first then
        C.notify(character, "IGUI_TCA_CannibalFirst");
    end
    if TCA.Sandbox.isCannibalTraitEnabled() and data.meals >= threshold then
        C.grantTrait(character, data);
    end
end

function C.getHarvestZPoints(cooked)
    local vars = SandboxVars.Cannibalism;
    local index = 1;
    if cooked then
        index = 2;
    end
    for _, key in ipairs(C.HARVESTZ_PRESET_ORDER) do
        if vars[key] then
            return C.HARVESTZ_PRESETS[key][index];
        end
    end
    if cooked then
        return tonumber(vars.CookedHumanMeatInsanityPointsGain) or 0;
    end
    return tonumber(vars.RawHumanMeatInsanityPointsGain) or 0;
end

function C.applyHarvestZ(character, organs, extras, cooked)
    local points = C.getHarvestZPoints(cooked);
    local multiplier = tonumber(SandboxVars.Cannibalism.EvolvedRecipeInsanityPointsMultiplier) or 1;
    local change = points * organs + points * extras * multiplier;
    if change <= 0 then
        return;
    end
    local args = {};
    args.change = change;
    if isServer() then
        sendServerCommand(character, "Cannibalism", "insanity", args);
    else
        triggerEvent("OnServerCommand", "Cannibalism", "insanity", args);
    end
end

function C.applyCZA(character, amount, cooked)
    local trait = C.getCZATrait();
    if not trait or not cooked or not character:hasTrait(trait) then
        return;
    end
    local md = character:getModData();
    md.CZA_cravingHours = math.max(0, (md.CZA_cravingHours or 0) - C.CZA_RELIEF * amount);
    C.addStat(character, CharacterStat.MORALE, C.CZA_MORALE * amount);
    C.addStat(character, CharacterStat.BOREDOM, -C.CZA_BOREDOM * amount);
    C.addStat(character, CharacterStat.STRESS, -math.min(1, C.CZA_RELIEF / 55) * amount);
end

function C.getRemaining(item)
    local base = item:getBaseHunger();
    local current = item:getHungChange();
    if base == 0 or current == 0 then
        return 1;
    end
    return math.max(0, math.min(1, current / base));
end

function C.getPortion(measured, percentage)
    local portion = math.max(0, math.min(1, tonumber(percentage) or 1));
    return math.min(portion, measured.remaining or 1);
end

function C.measure(item)
    local result = {};
    result.organs = 0;
    result.extras = 0;
    result.visible = 0;
    result.hidden = 0;
    result.infected = false;
    result.cooks = "";
    result.cooked = false;
    if not item or not instanceof(item, "Food") then
        return result;
    end
    if C.isOrganType(item:getFullType()) then
        result.organs = 1;
    end
    if item:haveExtraItems() then
        local extras = item:getExtraItems();
        for i = 0, extras:size() - 1 do
            local fullType = extras:get(i);
            if C.isOrganType(fullType) then
                result.visible = result.visible + 1;
            elseif C.isHiddenType(fullType) then
                result.hidden = result.hidden + 1;
                if fullType == C.HIDDEN_INFECTED then
                    result.infected = true;
                end
            end
        end
    end
    result.extras = result.visible + result.hidden;
    if result.organs == 0 and result.extras > 0 then
        local md = item:getModData();
        if md[C.DISH_INFECTED] == true then
            result.infected = true;
        end
        result.cooks = tostring(md[C.DISH_COOKS] or "");
    end
    result.cooked = C.isCooked(item);
    result.remaining = C.getRemaining(item);
    return result;
end

function C.getCookKey(character)
    return TCA.Exam.getObserverKey(character);
end

function C.isCook(character, measured)
    if measured.cooks == "" then
        return false;
    end
    local key = C.getCookKey(character);
    for entry in string.gmatch(measured.cooks, "[^;]+") do
        if entry == key then
            return true;
        end
    end
    return false;
end

function C.suspects(character)
    local firstAid = TCA.Sandbox.getSuspicionFirstAid();
    local cooking = TCA.Sandbox.getSuspicionCooking();
    if firstAid <= 10 and character:getPerkLevel(Perks.Doctor) >= firstAid then
        return true;
    end
    return cooking <= 10 and character:getPerkLevel(Perks.Cooking) >= cooking;
end

function C.isAware(character, measured)
    if measured.organs > 0 or measured.visible > 0 then
        return true;
    end
    if measured.hidden <= 0 then
        return false;
    end
    return C.isCook(character, measured) or C.suspects(character);
end

function C.onEaten(character, measured, portion)
    if not character or (measured.organs <= 0 and measured.extras <= 0) then
        return;
    end
    if measured.infected then
        TCA_OrganFood.infect(character);
    end
    local mod = C.getSupportedMod();
    if mod == "HarvestZCannibalism" then
        C.applyHarvestZ(character, measured.organs, measured.extras, measured.cooked);
        return;
    end
    local amount = (measured.organs + measured.extras * C.EVOLVED_FACTOR) * math.max(0, math.min(1, portion or 1));
    if amount <= 0 then
        return;
    end
    if mod == "CZA" then
        C.applyCZA(character, amount, measured.cooked);
    elseif TCA.Sandbox.areCannibalismEffectsEnabled() and C.isAware(character, measured) then
        C.applyOwn(character, amount);
    end
    C.flushStats(character);
end

function C.forEachPlayer(callback)
    if isClient() then
        return;
    end
    if isServer() then
        local players = getOnlinePlayers();
        if players then
            for i = 0, players:size() - 1 do
                callback(players:get(i));
            end
        end
        return;
    end
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i);
        if p then
            callback(p);
        end
    end
end

function C.tickPlayer(character)
    if not character or character:isDead() or C.getSupportedMod() then
        return;
    end
    if not TCA.Sandbox.areCannibalismEffectsEnabled() then
        return;
    end
    local data = character:getModData()[C.KEY];
    if type(data) ~= "table" then
        return;
    end
    local now = C.now();
    data.exposure = math.max(0, (data.exposure or 0) - C.EXPOSURE_DECAY_PER_DAY / 144);
    if C.hasOwnTrait(character) then
        local since = now - (data.last or now);
        if since > C.CRAVING_START_HOURS then
            local severity = math.min(1, (since - C.CRAVING_START_HOURS) / (C.CRAVING_FULL_HOURS - C.CRAVING_START_HOURS));
            local strength = TCA.Sandbox.getCannibalismStrength();
            C.raiseToFloor(character, CharacterStat.UNHAPPINESS, C.CRAVING_UNHAPPY * severity * strength, C.FLOOR_STEP_UNHAPPY);
            C.raiseToFloor(character, CharacterStat.BOREDOM, C.CRAVING_BOREDOM * severity * strength, C.FLOOR_STEP_BOREDOM);
            C.raiseToFloor(character, CharacterStat.STRESS, C.CRAVING_STRESS * severity * strength, C.FLOOR_STEP_STRESS);
        end
    elseif (data.guiltUntil or -1) > now then
        C.raiseToFloor(character, CharacterStat.UNHAPPINESS, data.guiltFloor or 0, C.FLOOR_STEP_UNHAPPY);
    end
    C.flushStats(character);
end

function C.everyTenMinutes()
    C.forEachPlayer(C.tickPlayer);
end

function C.addCook(dish, character)
    local md = dish:getModData();
    local key = C.getCookKey(character);
    local cooks = tostring(md[C.DISH_COOKS] or "");
    for entry in string.gmatch(cooks, "[^;]+") do
        if entry == key then
            return;
        end
    end
    if cooks == "" then
        md[C.DISH_COOKS] = key;
    else
        md[C.DISH_COOKS] = cooks .. ";" .. key;
    end
end

function C.disguise(dish, fullType, infected)
    local extras = dish:getExtraItems();
    if not extras then
        return false;
    end
    for i = extras:size() - 1, 0, -1 do
        if extras:get(i) == fullType then
            if infected then
                extras:set(i, C.HIDDEN_INFECTED);
            else
                extras:set(i, C.HIDDEN);
            end
            return true;
        end
    end
    return false;
end

function C.onOrganAdded(character, dish, recipe, fullType, infected)
    if not dish or not instanceof(dish, "Food") then
        return;
    end
    C.addCook(dish, character);
    if TCA.Sandbox.areOrgansHiddenInDishes() then
        if C.disguise(dish, fullType, infected) and not dish:isCustomName() then
            ISAddItemInRecipe.checkName(dish, recipe);
        end
    elseif infected then
        dish:getModData()[C.DISH_INFECTED] = true;
    end
    if isServer() then
        sendItemStats(dish);
        syncItemModData(character, dish);
    end
end

function C.getStat(character, stat)
    return character:getStats():get(stat);
end

function C.debugSnapshot(character)
    local s = {};
    local md = character:getModData();
    local data = md[C.KEY];
    if type(data) ~= "table" then
        data = {};
    end
    local now = C.now();
    local threshold = TCA.Sandbox.getCannibalTraitMeals();
    local exposure = data.exposure or 0;
    s.name = character:getDisplayName();
    s.stress = C.getStat(character, CharacterStat.STRESS);
    s.unhappy = C.getStat(character, CharacterStat.UNHAPPINESS);
    s.boredom = C.getStat(character, CharacterStat.BOREDOM);
    s.sickness = C.getStat(character, CharacterStat.FOOD_SICKNESS);
    s.morale = C.getStat(character, CharacterStat.MORALE);
    s.infected = character:getBodyDamage():IsInfected();
    s.infection = C.getStat(character, CharacterStat.ZOMBIE_INFECTION);
    s.mod = C.getSupportedMod() or "";
    s.effects = TCA.Sandbox.areCannibalismEffectsEnabled();
    s.strength = TCA.Sandbox.getCannibalismStrength();
    s.trait = C.hasOwnTrait(character);
    s.traitEnabled = TCA.Sandbox.isCannibalTraitEnabled();
    s.meals = data.meals or 0;
    s.threshold = threshold;
    s.exposure = exposure;
    s.habit = math.max(C.HABIT_MIN, 1 - exposure / math.max(1, threshold));
    s.sensitivity = C.getSensitivity(character);
    s.since = -1;
    if (data.last or -1) >= 0 then
        s.since = now - data.last;
    end
    s.guilt = math.max(0, (data.guiltUntil or -1) - now);
    s.guiltFloor = data.guiltFloor or 0;
    s.craving = 0;
    if s.trait and s.since > C.CRAVING_START_HOURS then
        s.craving = math.min(1, (s.since - C.CRAVING_START_HOURS) / (C.CRAVING_FULL_HOURS - C.CRAVING_START_HOURS));
    end
    s.firstAid = character:getPerkLevel(Perks.Doctor);
    s.firstAidReq = TCA.Sandbox.getSuspicionFirstAid();
    s.cooking = character:getPerkLevel(Perks.Cooking);
    s.cookingReq = TCA.Sandbox.getSuspicionCooking();
    s.suspects = C.suspects(character);
    s.hide = TCA.Sandbox.areOrgansHiddenInDishes();
    s.hzPoints = tonumber(md.Cannibalism_InsanityPoints) or -1;
    s.czaTrait = false;
    local czaTrait = C.getCZATrait();
    if czaTrait then
        s.czaTrait = character:hasTrait(czaTrait);
    end
    s.czaCraving = tonumber(md.CZA_cravingHours) or -1;
    return s;
end

function C.onDebugCommand(player, args)
    if not player or not args or not player:getRole():hasCapability(Capability.AddItem) then
        return;
    end
    local target = getPlayerByOnlineID(args.id);
    if not target then
        return;
    end
    local snapshot = C.debugSnapshot(target);
    snapshot.id = args.id;
    sendServerCommand(player, "TCA", "cannibalDebug", snapshot);
end

function C.keepOrganPoison(character, used, poison)
    if poison <= 0 or used:getHungChange() == 0 or used:getPoisonPower() >= poison then
        return;
    end
    used:setPoisonPower(poison);
    if isServer() then
        sendItemStats(used);
    end
end

C.originalAddComplete = C.originalAddComplete or ISAddItemInRecipe.complete;

function C.addComplete(self)
    local used = self.usedItem;
    local fullType = nil;
    local infected = false;
    if used and C.isOrganType(used:getFullType()) then
        fullType = used:getFullType();
        infected = used:getModData()["TCA_Infected"] == true and TCA_OrganFood.canInfect();
    end
    local poison = 0;
    local poisoner = nil;
    if fullType then
        poison = used:getPoisonPower();
        if self.baseItem then
            poisoner = self.baseItem:getModData()[C.POISONER_KEY];
        end
    end
    local result = C.originalAddComplete(self);
    if fullType then
        C.keepOrganPoison(self.character, used, poison);
        if self.baseItem and poisoner == nil then
            self.baseItem:getModData()[C.POISONER_KEY] = nil;
        end
        C.onOrganAdded(self.character, self.baseItem, self.recipe, fullType, infected);
    end
    return result;
end

ISAddItemInRecipe.complete = C.addComplete;

C.originalComplete = C.originalComplete or ISEatFoodAction.complete;
C.originalEat = C.originalEat or ISEatFoodAction.eat;

function C.complete(self)
    local measured = C.measure(self.item);
    local result = C.originalComplete(self);
    C.onEaten(self.character, measured, C.getPortion(measured, self.percentage or 1));
    return result;
end

function C.eat(self, food, percentage)
    local measured = C.measure(self.item);
    C.originalEat(self, food, percentage);
    local portion = tonumber(percentage) or 1;
    if portion > 0.95 then
        portion = 1;
    end
    C.onEaten(self.character, measured, C.getPortion(measured, (self.percentage or 1) * portion));
end

ISEatFoodAction.complete = C.complete;
ISEatFoodAction.eat = C.eat;

Events.EveryTenMinutes.Add(C.everyTenMinutes);
