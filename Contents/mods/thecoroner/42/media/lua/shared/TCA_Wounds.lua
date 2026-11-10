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

function W.getAmmoKey(weapon)
    if not weapon or not weapon:isRanged() then
        return nil;
    end
    local ammo = weapon:getAmmoType();
    if not ammo then
        return nil;
    end
    return ammo:getItemKey();
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

function W.encodeHit(time, part, kind, extra)
    local text = string.format("%.3f|%s|%s", time, part or "?", kind or "unknown");
    if extra and extra ~= "" then
        text = text .. "|" .. extra;
    end
    return text;
end

function W.decodeHit(str)
    if type(str) ~= "string" then
        return nil;
    end
    local fields = {};
    for field in string.gmatch(str, "[^|]+") do
        table.insert(fields, field);
    end
    if #fields < 3 or not tonumber(fields[1]) then
        return nil;
    end
    local hit = {};
    hit.time = tonumber(fields[1]);
    hit.part = fields[2];
    hit.kind = fields[3];
    hit.extra = fields[4];
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

function W.addHit(target, part, kind, extra)
    local md = target:getModData();
    if type(md[W.KEY_HITS]) ~= "table" then
        md[W.KEY_HITS] = {};
    end
    local hits = md[W.KEY_HITS];
    table.insert(hits, W.encodeHit(W.now(), part, kind, extra));
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
    W.addHit(zombie, part, W.getWeaponKind(weapon, zombie), W.getAmmoKey(weapon));
end

function W.onWeaponHitCharacter(wielder, target, weapon, damage)
    if isClient() or not target or not instanceof(target, "IsoPlayer") then
        return;
    end
    W.addHit(target, "?", W.getWeaponKind(weapon, target), W.getAmmoKey(weapon));
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

W.REGION_ORDER = { "w_Head", "w_Neck", "w_Torso_Upper", "w_UpperArm_R", "w_UpperArm_L", "w_Torso_Lower", "w_ForeArm_R", "w_ForeArm_L", "w_Groin", "w_Hand_R", "w_Hand_L", "w_UpperLeg_R", "w_UpperLeg_L", "w_LowerLeg_R", "w_LowerLeg_L", "w_Foot_R", "w_Foot_L" };
W.REGION_PARTS = {
    w_Hand_L = { Hand_L = true },
    w_Hand_R = { Hand_R = true },
    w_ForeArm_L = { ForeArm_L = true },
    w_ForeArm_R = { ForeArm_R = true },
    w_UpperArm_L = { UpperArm_L = true },
    w_UpperArm_R = { UpperArm_R = true },
    w_Torso_Upper = { Torso_Upper = true },
    w_Torso_Lower = { Torso_Lower = true },
    w_Head = { Head = true },
    w_Neck = { Neck = true },
    w_Groin = { Groin = true },
    w_UpperLeg_L = { UpperLeg_L = true },
    w_UpperLeg_R = { UpperLeg_R = true },
    w_LowerLeg_L = { LowerLeg_L = true },
    w_LowerLeg_R = { LowerLeg_R = true },
    w_Foot_L = { Foot_L = true },
    w_Foot_R = { Foot_R = true },
};
W.HIT_TO_WOUND = { firearm = "bullet", fire = "burn" };
W.UNKNOWN_PART_KINDS = { fire = "w_Torso_Upper" };
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

W.KEY_BULLETS = "TCA_Bullets";
W.BULLET_ITEM = "TCA.SpentBullet";
W.BULLET_RETAIN = 60;
W.BULLET_ORGANS = {
    Torso_Upper = { "heart", "lung_l", "lung_r" },
    Torso_Lower = { "liver", "stomach", "intestines", "pancreas", "kidney_l", "kidney_r", "spleen" },
    Groin = { "bladder", "intestines" },
};

function W.collectBulletSources(body)
    local sources = {};
    local hits = W.getHits(body);
    local lastAmmo = "";
    for i = 1, #hits do
        if hits[i].kind == "firearm" and hits[i].part == "?" and hits[i].extra then
            lastAmmo = hits[i].extra;
        end
    end
    local wounds = W.getWounds(body);
    for i = 1, #wounds do
        if wounds[i].kind == "bullet" and W.BULLET_ORGANS[wounds[i].part] then
            table.insert(sources, { part = wounds[i].part, ammo = lastAmmo });
        end
    end
    for i = 1, #hits do
        if hits[i].kind == "firearm" and W.BULLET_ORGANS[hits[i].part] then
            table.insert(sources, { part = hits[i].part, ammo = hits[i].extra or "" });
        end
    end
    return sources;
end

function W.pickRemainingOrgan(candidates, remaining)
    local pool = {};
    for i = 1, #candidates do
        if remaining[candidates[i]] then
            table.insert(pool, candidates[i]);
        end
    end
    if #pool == 0 then
        return nil;
    end
    return pool[ZombRand(#pool) + 1];
end

function W.ensureBullets(body, doneCount)
    local md = body:getModData();
    if type(md[W.KEY_BULLETS]) == "table" then
        return;
    end
    local remaining = {};
    for i = doneCount + 1, #TCA.Organs.LIST do
        remaining[TCA.Organs.LIST[i].id] = true;
    end
    local list = {};
    local sources = W.collectBulletSources(body);
    for i = 1, #sources do
        if ZombRand(100) < W.BULLET_RETAIN then
            local organ = W.pickRemainingOrgan(W.BULLET_ORGANS[sources[i].part], remaining);
            if organ then
                table.insert(list, organ .. "|" .. sources[i].ammo);
            end
        end
    end
    md[W.KEY_BULLETS] = list;
end

function W.takeBullets(body, organId, character)
    local list = body:getModData()[W.KEY_BULLETS];
    if type(list) ~= "table" then
        return 0;
    end
    local found = 0;
    local inv = character:getInventory();
    local i = 1;
    while i <= #list do
        local organ, ammo = string.match(list[i], "^([^|]+)|?(.*)$");
        if organ == organId then
            local item = instanceItem(W.BULLET_ITEM);
            if item then
                if ammo and ammo ~= "" then
                    item:getModData()["TCA_Ammo"] = ammo;
                end
                inv:AddItem(item);
                if isServer() then
                    sendAddItemToContainer(inv, item);
                end
                found = found + 1;
            end
            table.remove(list, i);
        else
            i = i + 1;
        end
    end
    return found;
end

function W.showBulletHalo(character, count)
    if not character then
        return;
    end
    HaloTextHelper.addGoodText(character, getText("IGUI_TCA_BulletFound", count));
end

function W.notifyBullets(character, count)
    if count <= 0 then
        return;
    end
    if isServer() then
        local args = {};
        args.count = count;
        sendServerCommand(character, "TCA", "bullets", args);
    else
        W.showBulletHalo(character, count);
    end
end

W.DEBUG_WOUND_KINDS = { "bite", "scratch", "laceration", "deep", "bullet", "glass", "burn", "fracture" };
W.DEBUG_HIT_KINDS = { "blunt", "blade", "axe", "spear", "firearm", "unarmed", "stomp" };
W.DEBUG_PARTS = { "Head", "Neck", "Torso_Upper", "Torso_Lower", "Groin", "UpperArm_L", "ForeArm_L", "Hand_L", "UpperArm_R", "ForeArm_R", "Hand_R", "UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R" };
W.DEBUG_HIT_PARTS = { "Head", "Torso_Upper", "Torso_Lower" };
W.DEBUG_AMMO = "Base.Bullets9mm";

function W.listContains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true;
        end
    end
    return false;
end

function W.debugClear(body)
    local md = body:getModData();
    md[W.KEY_WOUNDS] = {};
    md[W.KEY_HITS] = nil;
    md[W.KEY_BULLETS] = nil;
end

function W.debugAddWound(body, kind, part)
    local md = body:getModData();
    if type(md[W.KEY_WOUNDS]) ~= "table" then
        md[W.KEY_WOUNDS] = {};
    end
    table.insert(md[W.KEY_WOUNDS], W.encodeWound(part, kind));
    md[W.KEY_BULLETS] = nil;
end

function W.debugAddHit(body, kind, part)
    local extra = nil;
    if kind == "firearm" then
        extra = W.DEBUG_AMMO;
    end
    W.addHit(body, part, kind, extra);
    body:getModData()[W.KEY_BULLETS] = nil;
end

function W.debugRandomize(body)
    W.debugClear(body);
    local wounds = ZombRand(3) + 1;
    for i = 1, wounds do
        W.debugAddWound(body, W.DEBUG_WOUND_KINDS[ZombRand(#W.DEBUG_WOUND_KINDS) + 1], W.DEBUG_PARTS[ZombRand(#W.DEBUG_PARTS) + 1]);
    end
    local hits = ZombRand(4);
    for i = 1, hits do
        W.debugAddHit(body, W.DEBUG_HIT_KINDS[ZombRand(#W.DEBUG_HIT_KINDS) + 1], W.DEBUG_HIT_PARTS[ZombRand(#W.DEBUG_HIT_PARTS) + 1]);
    end
end

function W.debugApply(body, op, kind, part)
    if op == "clear" then
        W.debugClear(body);
    elseif op == "random" then
        W.debugRandomize(body);
    elseif op == "wound" and W.listContains(W.DEBUG_WOUND_KINDS, kind) and W.listContains(W.DEBUG_PARTS, part) then
        W.debugAddWound(body, kind, part);
    elseif op == "hit" and W.listContains(W.DEBUG_HIT_KINDS, kind) and W.listContains(W.DEBUG_HIT_PARTS, part) then
        W.debugAddHit(body, kind, part);
    else
        return false;
    end
    return true;
end

Events.OnCharacterDeath.Add(W.onCharacterDeath);
Events.OnHitZombie.Add(W.onHitZombie);
Events.OnWeaponHitCharacter.Add(W.onWeaponHitCharacter);
Events.OnPlayerGetDamage.Add(W.onPlayerGetDamage);
Events.OnZombieDead.Add(W.onZombieDead);
