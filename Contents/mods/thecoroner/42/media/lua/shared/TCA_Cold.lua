require "TimedActions/ISTransferAction";
require "TCA_DeathTime";
require "TCA_Morgue";

TCA = TCA or {};
TCA.Cold = TCA.Cold or {};

local C = TCA.Cold;
local D = TCA.DeathTime;

C.KEY_HOURS = "TCA_ColdHours";
C.KEY_LEFT = "TCA_ColdLeft";
C.KEY_STAY = "TCA_StayCold";
C.KEY_SINCE = "TCA_StaySince";

C.DECAY_FACTOR = 0.15;

C.drawers = C.drawers or {};

function C.isColdContainer(container, trustType)
    if not container or not TCA.Morgue.isOn(container) then
        return false;
    end
    if trustType then
        return true;
    end
    return container:isPowered();
end

function C.isDrawerContainer(container)
    return TCA.Morgue.getDrawerObject(container) ~= nil;
end

function C.settleItem(item, cold, now)
    if not item or not item:isHumanCorpse() then
        return;
    end
    local md = item:getModData();
    local since = md[C.KEY_SINCE];
    if since ~= nil then
        local elapsed = now - since;
        if elapsed > 0 then
            md[C.KEY_STAY] = (md[C.KEY_STAY] or 0) + elapsed;
        end
        md[C.KEY_SINCE] = nil;
    end
    if cold then
        md[C.KEY_SINCE] = now;
    end
end

function C.startStay(item, since)
    if not item then
        return;
    end
    item:getModData()[C.KEY_SINCE] = math.min(since, D.now());
end

function C.scanDrawer(obj, trustType)
    if isClient() or not obj then
        return;
    end
    local now = D.now();
    for i = 0, obj:getContainerCount() - 1 do
        local container = obj:getContainerByIndex(i);
        if container then
            local cold = C.isColdContainer(container, trustType);
            local items = container:getItems();
            for j = 0, items:size() - 1 do
                C.settleItem(items:get(j), cold, now);
            end
        end
    end
end

function C.getDrawerKey(obj)
    local sq = obj:getSquare();
    if not sq then
        return nil;
    end
    return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ();
end

function C.register(obj)
    if isClient() or not obj then
        return;
    end
    local key = C.getDrawerKey(obj);
    if not key then
        return;
    end
    local sq = obj:getSquare();
    local entry = {};
    entry.x = sq:getX();
    entry.y = sq:getY();
    entry.z = sq:getZ();
    C.drawers[key] = entry;
end

function C.onDrawerLoaded(obj)
    if isClient() then
        return;
    end
    C.register(obj);
    C.scanDrawer(obj, true);
end

function C.onEveryTenMinutes()
    if isClient() then
        return;
    end
    local cell = getCell();
    if not cell then
        return;
    end
    for key, entry in pairs(C.drawers) do
        local sq = cell:getGridSquare(entry.x, entry.y, entry.z);
        if sq then
            local obj = TCA.Morgue.findOnSquare(sq);
            if obj then
                C.scanDrawer(obj, false);
            else
                C.drawers[key] = nil;
            end
        end
    end
end

function C.mergeIntoBody(item, body)
    if not item or not body then
        return;
    end
    local now = D.now();
    C.settleItem(item, false, now);
    local imd = item:getModData();
    local stay = imd[C.KEY_STAY] or 0;
    imd[C.KEY_STAY] = nil;
    imd[C.KEY_SINCE] = nil;
    local bmd = body:getModData();
    bmd[C.KEY_STAY] = nil;
    bmd[C.KEY_SINCE] = nil;
    if stay > 0 then
        bmd[C.KEY_HOURS] = (bmd[C.KEY_HOURS] or 0) + stay;
        bmd[C.KEY_LEFT] = now;
    end
end

function C.getColdHours(body)
    return body:getModData()[C.KEY_HOURS] or 0;
end

function C.getHoursSinceLeft(body)
    local left = body:getModData()[C.KEY_LEFT];
    if left == nil then
        return nil;
    end
    return math.max(0, D.now() - left);
end

function C.getEffectiveHours(body, factor)
    local age = D.getHoursSinceDeath(body);
    local cold = math.min(C.getColdHours(body), age);
    return math.max(0, age - (1 - factor) * cold);
end

C.originalTransferItem = C.originalTransferItem or ISTransferAction.transferItem;

function C.transferItem(action, character, item, srcContainer, destContainer, dropSquare)
    local tracked = not isClient() and item ~= nil and item:isHumanCorpse();
    if tracked and C.isDrawerContainer(srcContainer) then
        C.settleItem(item, false, D.now());
    end
    local result = C.originalTransferItem(action, character, item, srcContainer, destContainer, dropSquare);
    if tracked and C.isDrawerContainer(destContainer) then
        C.settleItem(item, C.isColdContainer(destContainer, false), D.now());
    end
    return result;
end

ISTransferAction.transferItem = C.transferItem;

Events.EveryTenMinutes.Add(C.onEveryTenMinutes);
