require "TimedActions/ISTransferAction";
require "TimedActions/ISGrabCorpseItem";

TCA = TCA or {};
TCA.DeathTime = TCA.DeathTime or {};

local D = TCA.DeathTime;

D.KEY_TIME = "TCA_DeathTime";
D.KEY_KNOWN = "TCA_DeathKnown";
D.KEY_INFECTED = "TCA_Infected";

D.OUTBREAK_LEAD_DAYS = 5;
D.MORGUE_WINDOW_DAYS = 7;
D.REANIMATION_MAX_HOURS = 12;

D.ZOMBIFIED_DAYS = {
    [1] = { 0, 30 },
    [2] = { 20, 90 },
    [3] = { 60, 240 },
};
D.SKELETON_DAYS = { 180, 720 };

function D.now()
    return getGameTime():getWorldAgeHours();
end

function D.getOutbreakStart()
    local months = getSandboxOptions():getTimeSinceApo() - 1;
    return -((months * 30 + D.OUTBREAK_LEAD_DAYS) * 24);
end

function D.has(target)
    return target:getModData()[D.KEY_TIME] ~= nil;
end

function D.get(body)
    local stored = body:getModData()[D.KEY_TIME];
    if stored ~= nil then
        return stored;
    end
    return body:getDeathTime();
end

function D.getHoursSinceDeath(body)
    return math.max(0, D.now() - D.get(body));
end

function D.isKnown(body)
    return body:getModData()[D.KEY_KNOWN] == true;
end

function D.record(target, deathTime, known)
    local md = target:getModData();
    md[D.KEY_TIME] = deathTime;
    md[D.KEY_KNOWN] = known;
end

function D.getRotStage(character)
    local visual = character:getHumanVisual();
    if not visual then
        return 1;
    end
    local texture = visual:getSkinTexture();
    if not texture then
        return 1;
    end
    local stage = tonumber(string.match(texture, "_level(%d)"));
    if not stage or stage < 1 or stage > 3 then
        return 1;
    end
    return stage;
end

function D.randomBetween(minValue, maxValue)
    if maxValue <= minValue then
        return minValue;
    end
    return ZombRandFloat(minValue, maxValue);
end

function D.inventZombieDeath(character, killTime)
    local available = killTime - D.getOutbreakStart();
    if available <= 0 then
        return killTime;
    end
    local range = D.ZOMBIFIED_DAYS[D.getRotStage(character)];
    if character:isSkeleton() then
        range = D.SKELETON_DAYS;
    end
    local minHours = range[1] * 24;
    local maxHours = math.min(range[2] * 24, available);
    if minHours > maxHours then
        minHours = maxHours * 0.5;
    end
    local zombified = D.randomBetween(minHours, maxHours);
    local delay = D.randomBetween(0, D.REANIMATION_MAX_HOURS);
    return math.max(D.getOutbreakStart(), killTime - zombified - delay);
end

function D.inventMorgueDeath()
    local start = D.getOutbreakStart();
    local deathTime = start + D.randomBetween(0, D.MORGUE_WINDOW_DAYS * 24);
    return math.min(deathTime, D.now());
end

function D.ensure(body)
    if not body or body:isAnimal() then
        return;
    end
    if not D.has(body) then
        D.ensureInternal(body);
    end
    if TCA.Wounds then
        TCA.Wounds.ensureBody(body);
    end
end

function D.ensureInternal(body)
    local md = body:getModData();
    if body:isZombie() then
        D.record(body, D.inventZombieDeath(body, body:getDeathTime()), false);
        if md[D.KEY_INFECTED] == nil then
            md[D.KEY_INFECTED] = true;
        end
        return;
    end
    D.record(body, body:getDeathTime(), false);
end

D.SYNC_DELAYS_MS = { 1000, 5000 };
D.syncQueue = {};

function D.queueBodySync(character)
    if not isServer() then
        return;
    end
    local sq = character:getCurrentSquare();
    if not sq then
        return;
    end
    local entry = {};
    entry.x = sq:getX();
    entry.y = sq:getY();
    entry.z = sq:getZ();
    entry.start = getTimestampMs();
    entry.step = 1;
    table.insert(D.syncQueue, entry);
end

function D.transmitBodiesAround(entry)
    local cell = getCell();
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(entry.x + dx, entry.y + dy, entry.z);
            local bodies = sq and sq:getDeadBodys();
            if bodies then
                for i = 0, bodies:size() - 1 do
                    local body = bodies:get(i);
                    if body and not body:isAnimal() and D.has(body) then
                        body:transmitModData();
                    end
                end
            end
        end
    end
end

function D.onServerTick()
    if #D.syncQueue == 0 then
        return;
    end
    local now = getTimestampMs();
    local remaining = {};
    for _, entry in ipairs(D.syncQueue) do
        if now - entry.start >= D.SYNC_DELAYS_MS[entry.step] then
            D.transmitBodiesAround(entry);
            entry.step = entry.step + 1;
        end
        if entry.step <= #D.SYNC_DELAYS_MS then
            table.insert(remaining, entry);
        end
    end
    D.syncQueue = remaining;
end

function D.onCharacterDeath(character)
    if isClient() or not character or instanceof(character, "IsoAnimal") then
        return;
    end
    D.queueBodySync(character);
    if D.has(character) then
        return;
    end
    local md = character:getModData();
    if instanceof(character, "IsoZombie") then
        D.record(character, D.inventZombieDeath(character, D.now()), false);
        if md[D.KEY_INFECTED] == nil then
            md[D.KEY_INFECTED] = true;
        end
        return;
    end
    D.record(character, D.now(), true);
    if md[D.KEY_INFECTED] == nil then
        local bodyDamage = character:getBodyDamage();
        md[D.KEY_INFECTED] = bodyDamage ~= nil and bodyDamage:IsInfected();
    end
end

function D.onLoadGridsquare(square)
    if isClient() or not square then
        return;
    end
    local bodies = square:getDeadBodys();
    if not bodies then
        return;
    end
    for i = 0, bodies:size() - 1 do
        D.ensure(bodies:get(i));
    end
end

function D.prepareCorpseItem(item, restartClock, viaGrab)
    if not item or not item:isHumanCorpse() then
        return;
    end
    local body = item:loadCorpseFromByteData(nil);
    if not body then
        return;
    end
    D.ensure(body);
    local coldStay = 0;
    if TCA.Cold then
        coldStay = TCA.Cold.mergeIntoBody(item, body);
    end
    if restartClock then
        if TCA.Rot then
            TCA.Rot.log("corpse leaves a container (grab = " .. tostring(viaGrab == true) .. ")");
            TCA.Rot.applyExitAge(body, coldStay);
            if viaGrab then
                TCA.Rot.markPending(body);
            end
        else
            body:setDeathTime(D.now());
        end
    end
    item:storeInByteData(body);
end

D.originalTransferItem = D.originalTransferItem or ISTransferAction.transferItem;
D.originalGrabComplete = D.originalGrabComplete or ISGrabCorpseItem.complete;

function D.transferItem(action, character, item, srcContainer, destContainer, dropSquare)
    if not isClient() and destContainer and destContainer:getType() == "floor" and item and item:isHumanCorpse() then
        D.prepareCorpseItem(item, true);
    end
    return D.originalTransferItem(action, character, item, srcContainer, destContainer, dropSquare);
end

function D.grabComplete(action)
    if not isClient() and action.item and action.item:isHumanCorpse() then
        D.prepareCorpseItem(action.item, true, true);
    end
    return D.originalGrabComplete(action);
end

ISTransferAction.transferItem = D.transferItem;
ISGrabCorpseItem.complete = D.grabComplete;

Events.OnCharacterDeath.Add(D.onCharacterDeath);
Events.OnTick.Add(D.onServerTick);
Events.LoadGridsquare.Add(D.onLoadGridsquare);
