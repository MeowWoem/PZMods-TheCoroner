require "TCA_Shared";

TCA = TCA or {};
TCA.Wounds = TCA.Wounds or {};

local W = TCA.Wounds;

W.KEY_HITS = "TCA_Hits";
W.KEY_WOUNDS = "TCA_Wounds";
W.KEY_CAUSE = "TCA_FinalCause";
W.MAX_HITS = 40;
W.KILL_WINDOW = 0.05;
W.REPEAT_WINDOW = 0.25;
W.TRANSMISSION_EVERYONE = 3;

W.BITE_PARTS = {
    { part = "Hand_L", weight = 12 }, { part = "Hand_R", weight = 12 },
    { part = "ForeArm_L", weight = 12 }, { part = "ForeArm_R", weight = 12 },
    { part = "UpperArm_L", weight = 6 }, { part = "UpperArm_R", weight = 6 },
    { part = "Neck", weight = 12 }, { part = "Head", weight = 4 },
    { part = "Torso_Upper", weight = 8 }, { part = "Torso_Lower", weight = 4 },
    { part = "UpperLeg_L", weight = 3 }, { part = "UpperLeg_R", weight = 3 },
    { part = "LowerLeg_L", weight = 3 }, { part = "LowerLeg_R", weight = 3 },
};

W.SCRATCH_PARTS = { "Hand_L", "Hand_R", "ForeArm_L", "ForeArm_R" };

W.NATURAL_CAUSES = {
    { cause = "natural", weight = 40 },
    { cause = "firearm", weight = 20 },
    { cause = "blunt", weight = 15 },
    { cause = "blade", weight = 15 },
    { cause = "fall", weight = 10 },
};

function W.now()
    return getGameTime():getWorldAgeHours();
end

function W.pickWeighted(list)
    local total = 0;
    for i = 1, #list do
        total = total + list[i].weight;
    end
    local roll = ZombRand(total);
    for i = 1, #list do
        roll = roll - list[i].weight;
        if roll < 0 then
            return list[i];
        end
    end
    return list[#list];
end

function W.getWeaponKind(weapon, target)
    if not weapon then
        return "unknown";
    end
    if weapon:isRanged() then
        return "firearm";
    end
    if weapon:isBareHands() then
        if target and (target:isOnFloor() or target:isKnockedDown()) then
            return "stomp";
        end
        return "unarmed";
    end
    if weapon:isOfWeaponCategory(WeaponCategory.AXE) then
        return "axe";
    end
    if weapon:isOfWeaponCategory(WeaponCategory.LONG_BLADE) or weapon:isOfWeaponCategory(WeaponCategory.SMALL_BLADE) then
        return "blade";
    end
    if weapon:isOfWeaponCategory(WeaponCategory.SPEAR) then
        return "spear";
    end
    return "blunt";
end

function W.encodeHit(time, part, kind)
    return string.format("%.3f|%s|%s", time, part or "?", kind or "unknown");
end

function W.decodeHit(str)
    if type(str) ~= "string" then
        return nil;
    end
    local t, part, kind = string.match(str, "^([%-%d%.]+)|([^|]+)|([^|]+)$");
    if not t then
        return nil;
    end
    local hit = {};
    hit.time = tonumber(t);
    hit.part = part;
    hit.kind = kind;
    return hit;
end

function W.getHits(target)
    local hits = target:getModData()[W.KEY_HITS];
    if type(hits) ~= "table" then
        return {};
    end
    local list = {};
    for i = 1, #hits do
        local hit = W.decodeHit(hits[i]);
        if hit then
            table.insert(list, hit);
        end
    end
    return list;
end

function W.getLastHit(target)
    local hits = target:getModData()[W.KEY_HITS];
    if type(hits) ~= "table" or #hits == 0 then
        return nil;
    end
    return W.decodeHit(hits[#hits]);
end

function W.addHit(target, part, kind)
    local md = target:getModData();
    if type(md[W.KEY_HITS]) ~= "table" then
        md[W.KEY_HITS] = {};
    end
    local hits = md[W.KEY_HITS];
    table.insert(hits, W.encodeHit(W.now(), part, kind));
    while #hits > W.MAX_HITS do
        table.remove(hits, 1);
    end
end

function W.addHitThrottled(target, part, kind)
    local last = W.getLastHit(target);
    if last and last.kind == kind and W.now() - last.time < W.REPEAT_WINDOW then
        return;
    end
    W.addHit(target, part, kind);
end

function W.encodeWound(part, kind)
    return part .. "|" .. kind;
end

function W.decodeWound(str)
    if type(str) ~= "string" then
        return nil;
    end
    local part, kind = string.match(str, "^([^|]+)|([^|]+)$");
    if not part then
        return nil;
    end
    local wound = {};
    wound.part = part;
    wound.kind = kind;
    return wound;
end

function W.getWounds(target)
    local stored = target:getModData()[W.KEY_WOUNDS];
    if type(stored) ~= "table" then
        return {};
    end
    local list = {};
    for i = 1, #stored do
        local wound = W.decodeWound(stored[i]);
        if wound then
            table.insert(list, wound);
        end
    end
    return list;
end

function W.hasWounds(target)
    return type(target:getModData()[W.KEY_WOUNDS]) == "table";
end

function W.addPartWounds(list, part, name)
    if part:bitten() then
        table.insert(list, W.encodeWound(name, "bite"));
    end
    if part:scratched() then
        table.insert(list, W.encodeWound(name, "scratch"));
    end
    if part:isCut() then
        table.insert(list, W.encodeWound(name, "laceration"));
    end
    if part:isDeepWounded() then
        table.insert(list, W.encodeWound(name, "deep"));
    end
    if part:haveBullet() then
        table.insert(list, W.encodeWound(name, "bullet"));
    end
    if part:haveGlass() then
        table.insert(list, W.encodeWound(name, "glass"));
    end
    if part:isBurnt() or part:getBurnTime() > 0 then
        table.insert(list, W.encodeWound(name, "burn"));
    end
    if part:getFractureTime() > 0 then
        table.insert(list, W.encodeWound(name, "fracture"));
    end
end

function W.snapshotPlayer(player)
    local bodyDamage = player:getBodyDamage();
    if not bodyDamage then
        return;
    end
    local list = {};
    local parts = bodyDamage:getBodyParts();
    for i = 0, parts:size() - 1 do
        local part = parts:get(i);
        W.addPartWounds(list, part, BodyPartType.ToString(part:getType()));
    end
    player:getModData()[W.KEY_WOUNDS] = list;
end

function W.inventBite(list)
    table.insert(list, W.encodeWound(W.pickWeighted(W.BITE_PARTS).part, "bite"));
    local scratches = ZombRand(3);
    for i = 1, scratches do
        table.insert(list, W.encodeWound(W.SCRATCH_PARTS[ZombRand(#W.SCRATCH_PARTS) + 1], "scratch"));
    end
end

function W.inventCause(list)
    local cause = W.pickWeighted(W.NATURAL_CAUSES).cause;
    if cause == "firearm" then
        local part = "Torso_Upper";
        if ZombRand(4) == 0 then
            part = "Head";
        end
        table.insert(list, W.encodeWound(part, "bullet"));
    elseif cause == "blunt" then
        table.insert(list, W.encodeWound("Head", "laceration"));
        table.insert(list, W.encodeWound("Head", "fracture"));
    elseif cause == "blade" then
        table.insert(list, W.encodeWound("Torso_Upper", "deep"));
        if ZombRand(2) == 0 then
            table.insert(list, W.encodeWound("ForeArm_L", "laceration"));
        end
    elseif cause == "fall" then
        table.insert(list, W.encodeWound("LowerLeg_R", "fracture"));
        table.insert(list, W.encodeWound("Head", "laceration"));
    end
    return cause;
end

function W.everyoneInfected()
    local lore = SandboxVars and SandboxVars.ZombieLore;
    return lore ~= nil and lore.Transmission == W.TRANSMISSION_EVERYONE;
end

function W.ensureWounds(target)
    if not target or W.hasWounds(target) then
        return;
    end
    local list = {};
    local md = target:getModData();
    local infected = md["TCA_Infected"];
    if infected == nil then
        infected = target:isZombie();
    end
    if infected and not W.everyoneInfected() then
        W.inventBite(list);
        if md[W.KEY_CAUSE] == nil and not instanceof(target, "IsoZombie") then
            md[W.KEY_CAUSE] = "infection";
        end
    else
        local cause = W.inventCause(list);
        if md[W.KEY_CAUSE] == nil then
            md[W.KEY_CAUSE] = cause;
        end
    end
    md[W.KEY_WOUNDS] = list;
end

function W.ensureBody(body)
    if isClient() or not body or body:isAnimal() then
        return;
    end
    W.ensureWounds(body);
end

function W.getDeathCause(character)
    local last = W.getLastHit(character);
    if last and W.now() - last.time <= W.KILL_WINDOW then
        return last.kind;
    end
    if character:isOnFire() then
        return "fire";
    end
    if instanceof(character, "IsoPlayer") then
        local bodyDamage = character:getBodyDamage();
        if bodyDamage and bodyDamage:IsInfected() then
            return "infection";
        end
    end
    return "unknown";
end

function W.onCharacterDeath(character)
    if isClient() or not character or instanceof(character, "IsoAnimal") then
        return;
    end
    local md = character:getModData();
    if instanceof(character, "IsoPlayer") and not W.hasWounds(character) then
        W.snapshotPlayer(character);
    end
    if instanceof(character, "IsoZombie") then
        W.ensureWounds(character);
    end
    md[W.KEY_CAUSE] = W.getDeathCause(character);
end

function W.onHitZombie(zombie, wielder, bodyPart, weapon)
    if isClient() or not zombie then
        return;
    end
    local part = "?";
    if bodyPart then
        part = BodyPartType.ToString(bodyPart);
    end
    W.addHit(zombie, part, W.getWeaponKind(weapon, zombie));
end

function W.onWeaponHitCharacter(wielder, target, weapon, damage)
    if isClient() or not target or not instanceof(target, "IsoPlayer") then
        return;
    end
    W.addHit(target, "?", W.getWeaponKind(weapon, target));
end

function W.onPlayerGetDamage(character, damageType, damage)
    if isClient() or not character or not instanceof(character, "IsoPlayer") then
        return;
    end
    if damageType == "FALLDOWN" then
        W.addHit(character, "?", "fall");
    elseif damageType == "CARHITDAMAGE" or damageType == "CARCRASHDAMAGE" then
        W.addHitThrottled(character, "?", "vehicle");
    elseif damageType == "FIRE" then
        W.addHitThrottled(character, "?", "fire");
    end
end

function W.onZombieDead(zombie)
    if isClient() or not zombie then
        return;
    end
    if zombie:isOnFire() then
        W.addHitThrottled(zombie, "?", "fire");
    end
end

function W.describe(body)
    local lines = {};
    local deathTime = TCA.DeathTime.get(body);
    table.insert(lines, "cause=" .. tostring(body:getModData()[W.KEY_CAUSE]));
    local wounds = W.getWounds(body);
    for i = 1, #wounds do
        table.insert(lines, "wound " .. wounds[i].part .. " " .. wounds[i].kind);
    end
    local hits = W.getHits(body);
    for i = 1, #hits do
        local when = "post";
        if hits[i].time <= deathTime then
            when = "ante";
        end
        table.insert(lines, string.format("hit %s %s %s %.1fh", when, hits[i].part, hits[i].kind, W.now() - hits[i].time));
    end
    return lines;
end

W.REGION_ORDER = { "w_head", "w_torso", "w_arm_r", "w_arm_l", "w_leg_r", "w_leg_l" };
W.REGION_PARTS = {
    w_head = { Head = true, Neck = true },
    w_torso = { Torso_Upper = true, Torso_Lower = true, Groin = true },
    w_arm_r = { UpperArm_R = true, ForeArm_R = true, Hand_R = true },
    w_arm_l = { UpperArm_L = true, ForeArm_L = true, Hand_L = true },
    w_leg_r = { UpperLeg_R = true, LowerLeg_R = true, Foot_R = true },
    w_leg_l = { UpperLeg_L = true, LowerLeg_L = true, Foot_L = true },
};
W.HIT_TO_WOUND = { firearm = "bullet", fire = "burn" };
W.UNKNOWN_PART_KINDS = { fire = "w_torso" };
W.DETECT = { scratch = 0.35, glass = 0.4, bite = 0.7 };
W.DETECT_DEFAULT = 0.6;
W.DETECT_PER_LEVEL = 0.06;
W.CONFUSE = {
    blade = "axe", axe = "blade", spear = "blade",
    blunt = "unarmed", unarmed = "blunt", stomp = "blunt",
    bite = "laceration", laceration = "bite", scratch = "laceration",
};
W.IDENTIFY_LEVEL = 5;
W.COUNT_LEVEL = 4;
W.TIMING_LEVEL = 6;

function W.isRegion(id)
    return W.REGION_PARTS[id] ~= nil;
end

function W.getRegionGroups(body, regionId)
    local parts = W.REGION_PARTS[regionId];
    local groups = {};
    local index = {};
    local deathTime = TCA.DeathTime.get(body);
    local entries = {};
    local wounds = W.getWounds(body);
    for i = 1, #wounds do
        if parts[wounds[i].part] then
            table.insert(entries, { kind = wounds[i].kind, post = false });
        end
    end
    local hits = W.getHits(body);
    for i = 1, #hits do
        local hit = hits[i];
        local inRegion = parts[hit.part] == true;
        if hit.part == "?" and W.UNKNOWN_PART_KINDS[hit.kind] == regionId then
            inRegion = true;
        end
        if inRegion then
            table.insert(entries, { kind = W.HIT_TO_WOUND[hit.kind] or hit.kind, post = hit.time > deathTime });
        end
    end
    for i = 1, #entries do
        local e = entries[i];
        local key = e.kind .. ":" .. tostring(e.post);
        local group = index[key];
        if not group then
            group = { kind = e.kind, post = e.post, count = 0 };
            index[key] = group;
            table.insert(groups, group);
        end
        group.count = group.count + 1;
    end
    return groups;
end

function W.readRegion(body, regionId, level)
    local E = TCA.Exam;
    local readings = {};
    local groups = W.getRegionGroups(body, regionId);
    for i = 1, #groups do
        local g = groups[i];
        local key = regionId .. ":" .. g.kind .. ":" .. tostring(g.post);
        local chance = math.min(1, (W.DETECT[g.kind] or W.DETECT_DEFAULT) + level * W.DETECT_PER_LEVEL);
        if (E.noise(body, key .. ":d", level) + 1) / 2 < chance then
            local reading = { kind = g.kind, post = g.post, count = g.count };
            if level < W.IDENTIFY_LEVEL and W.CONFUSE[g.kind] and math.abs(E.noise(body, key .. ":m", level)) < E.getMisreadChance(level) then
                reading.kind = W.CONFUSE[g.kind];
            end
            table.insert(readings, reading);
        end
    end
    return readings;
end

function W.formatReading(reading, level)
    local text = getText("IGUI_TCA_Wound_" .. reading.kind);
    if reading.count > 1 then
        if level >= W.COUNT_LEVEL then
            text = text .. " " .. getText("IGUI_TCA_WoundCount", reading.count);
        else
            text = text .. " " .. getText("IGUI_TCA_WoundSeveral");
        end
    end
    if level >= W.TIMING_LEVEL then
        if reading.post then
            text = text .. ", " .. getText("IGUI_TCA_WoundPost");
        else
            text = text .. ", " .. getText("IGUI_TCA_WoundAnte");
        end
    end
    return text;
end

function W.getRegionText(body, regionId, level)
    local readings = W.readRegion(body, regionId, level);
    if #readings == 0 then
        return getText("IGUI_TCA_WoundNone");
    end
    local parts = {};
    for i = 1, #readings do
        table.insert(parts, W.formatReading(readings[i], level));
    end
    return table.concat(parts, " ; ") .. ".";
end

function W.regionShowsBite(body, regionId, level)
    local readings = W.readRegion(body, regionId, level);
    for i = 1, #readings do
        if readings[i].kind == "bite" then
            return true;
        end
    end
    return false;
end

Events.OnCharacterDeath.Add(W.onCharacterDeath);
Events.OnHitZombie.Add(W.onHitZombie);
Events.OnWeaponHitCharacter.Add(W.onWeaponHitCharacter);
Events.OnPlayerGetDamage.Add(W.onPlayerGetDamage);
Events.OnZombieDead.Add(W.onZombieDead);
