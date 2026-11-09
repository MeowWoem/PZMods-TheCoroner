require "TCA_Shared";
require "TCA_DeathTime";
require "TCA_Cold";

TCA = TCA or {};
TCA.Rot = TCA.Rot or {};

local R = TCA.Rot;

R.TABLE_AGE_CAP = 0.8;
R.EXIT_AGE_CAP = 2 / 3;

R.KEY_PENDING_AGE = "TCA_PendingAge";
R.KEY_PENDING_AT = "TCA_PendingAt";

R.TICK_INTERVAL = 20;

R.squares = R.squares or {};
R.pending = R.pending or {};
R.tickCount = 0;

function R.getRemovalHours()
    local hours = nil;
    if SandboxVars then
        hours = tonumber(SandboxVars.HoursForCorpseRemoval);
    end
    if hours == nil then
        local option = getSandboxOptions():getOptionByName("HoursForCorpseRemoval");
        if option then
            hours = tonumber(option:getValue());
        end
    end
    return hours or -1;
end

function R.getVanillaAge(body)
    return TCA.DeathTime.now() - body:getDeathTime();
end

function R.setVanillaAge(body, age)
    body:setDeathTime(TCA.DeathTime.now() - math.max(0, age));
end

function R.isOnTable(body)
    if not body or not body:getModData()["TCA_OnTable"] then
        return false;
    end
    if TCA.isBodyOnFloor(body) then
        return false;
    end
    return TCA.findTableOnSquare(body:getSquare()) ~= nil;
end

function R.guardBody(body)
    local removal = R.getRemovalHours();
    if removal <= 0 then
        return;
    end
    local cap = removal * R.TABLE_AGE_CAP;
    if R.getVanillaAge(body) > cap then
        R.setVanillaAge(body, cap);
    end
end

function R.getSquareKey(sq)
    return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ();
end

function R.register(sq)
    if isClient() or not sq then
        return;
    end
    local entry = {};
    entry.x = sq:getX();
    entry.y = sq:getY();
    entry.z = sq:getZ();
    R.squares[R.getSquareKey(sq)] = entry;
end

function R.guardSquare(sq)
    local bodies = sq:getDeadBodys();
    if not bodies then
        return false;
    end
    local found = false;
    for i = 0, bodies:size() - 1 do
        local body = bodies:get(i);
        if R.isOnTable(body) then
            R.guardBody(body);
            found = true;
        end
    end
    return found;
end

function R.markPending(body)
    local md = body:getModData();
    md[R.KEY_PENDING_AGE] = math.max(0, R.getVanillaAge(body));
    md[R.KEY_PENDING_AT] = TCA.DeathTime.now();
end

function R.applyPending(body)
    if not body then
        return;
    end
    local md = body:getModData();
    local pending = md[R.KEY_PENDING_AGE];
    if pending == nil then
        return;
    end
    local at = md[R.KEY_PENDING_AT] or TCA.DeathTime.now();
    md[R.KEY_PENDING_AGE] = nil;
    md[R.KEY_PENDING_AT] = nil;
    local removal = R.getRemovalHours();
    if removal <= 0 then
        return;
    end
    local age = pending + math.max(0, TCA.DeathTime.now() - at);
    R.setVanillaAge(body, math.min(age, removal * R.EXIT_AGE_CAP));
end

function R.applyPendingOnSquare(sq)
    if not sq then
        return;
    end
    local bodies = sq:getDeadBodys();
    if not bodies then
        return;
    end
    for i = 0, bodies:size() - 1 do
        R.applyPending(bodies:get(i));
    end
end

function R.queueSquare(sq)
    if isClient() or not sq then
        return;
    end
    local entry = {};
    entry.x = sq:getX();
    entry.y = sq:getY();
    entry.z = sq:getZ();
    R.pending[R.getSquareKey(sq)] = entry;
end

function R.onTick()
    if not next(R.pending) then
        R.tickCount = 0;
        return;
    end
    R.tickCount = R.tickCount + 1;
    if R.tickCount < R.TICK_INTERVAL then
        return;
    end
    R.tickCount = 0;
    local cell = getCell();
    local list = R.pending;
    R.pending = {};
    if not cell then
        return;
    end
    for _, entry in pairs(list) do
        for dx = -1, 1 do
            for dy = -1, 1 do
                R.applyPendingOnSquare(cell:getGridSquare(entry.x + dx, entry.y + dy, entry.z));
            end
        end
    end
end

function R.onDeadBodySpawn(body)
    if isClient() or not body then
        return;
    end
    if body:getModData()[R.KEY_PENDING_AGE] ~= nil then
        R.queueSquare(body:getSquare());
    end
end

function R.onCharacterDeath(character)
    if isClient() or not character then
        return;
    end
    if character:getModData()[R.KEY_PENDING_AGE] ~= nil then
        R.queueSquare(character:getCurrentSquare());
    end
end

function R.onLoadGridsquare(sq)
    if isClient() or not sq then
        return;
    end
    R.applyPendingOnSquare(sq);
    if R.guardSquare(sq) then
        R.register(sq);
    end
end

function R.onEveryOneMinute()
    if isClient() then
        return;
    end
    local cell = getCell();
    if not cell then
        return;
    end
    for key, entry in pairs(R.squares) do
        local sq = cell:getGridSquare(entry.x, entry.y, entry.z);
        if not sq or not R.guardSquare(sq) then
            R.squares[key] = nil;
        end
    end
end

function R.applyExitAge(body, coldStay)
    local removal = R.getRemovalHours();
    if removal <= 0 then
        body:setDeathTime(TCA.DeathTime.now());
        return;
    end
    local age = R.getVanillaAge(body);
    local slowed = math.min(math.max(coldStay or 0, 0), math.max(age, 0)) * (1 - TCA.Cold.DECAY_FACTOR);
    local effective = math.max(0, age - slowed);
    R.setVanillaAge(body, math.min(effective, removal * R.EXIT_AGE_CAP));
end

Events.LoadGridsquare.Add(R.onLoadGridsquare);
Events.EveryOneMinute.Add(R.onEveryOneMinute);
Events.OnTick.Add(R.onTick);
Events.OnDeadBodySpawn.Add(R.onDeadBodySpawn);
Events.OnCharacterDeath.Add(R.onCharacterDeath);
