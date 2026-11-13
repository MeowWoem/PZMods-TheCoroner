require "TCA_Shared";

TCA = TCA or {};
TCA.TableThrow = TCA.TableThrow or {};

local T = TCA.TableThrow;

T.CONTAINER_TYPE = "crate";
T.CONTAINER_CAPACITY = 50;
T.LOCAL_TIMEOUT_MS = 15000;
T.serverPending = T.serverPending or {};
T.localPending = T.localPending or {};

function T.newContainer(tableObj)
    local container = ItemContainer.new(T.CONTAINER_TYPE, tableObj:getSquare(), tableObj);
    container:setCapacity(T.CONTAINER_CAPACITY);
    container:setExplored(true);
    return container;
end

function T.canThrow(character, tableObj)
    if not character or not character:isDraggingCorpse() then
        return false;
    end
    if not tableObj or not tableObj:getSquare() or tableObj:getObjectIndex() < 0 then
        return false;
    end
    if not TCA.isLongTable(tableObj) or TCA.tableHasBody(tableObj) then
        return false;
    end
    if TCA.getTableClutter(tableObj) then
        return false;
    end
    return true;
end

function T.findCorpseItem(container)
    local items = container:getItems();
    for i = 0, items:size() - 1 do
        local item = items:get(i);
        if item:isHumanCorpse() then
            return item;
        end
    end
    return nil;
end

function T.placeItemOnTable(character, item, container, tableObj)
    container:Remove(item);
    local sq = tableObj:getSquare();
    local body = sq:tryAddCorpseToWorld(item, 0.5, 0.5);
    if not body then
        return false;
    end
    if TCA.tableHasBody(tableObj) or TCA.getTableClutter(tableObj) then
        return false;
    end
    return TCA.placeBodyOnTable(body, tableObj, character);
end

function T.registerServer(character, grappled, tableObj)
    if not character or not grappled or not tableObj then
        return;
    end
    local entry = {};
    entry.grappled = grappled;
    entry.tableObject = tableObj;
    T.serverPending[character:getOnlineID()] = entry;
end

function T.onClientCommand(module, command, player, args)
    if module ~= "deadBody" or command ~= "addBody" or not player then
        return;
    end
    local id = player:getOnlineID();
    local entry = T.serverPending[id];
    if not entry then
        return;
    end
    T.serverPending[id] = nil;
    local container = T.newContainer(entry.tableObject);
    local item = entry.grappled:becomeCorpseItem(container, player);
    if not item then
        return;
    end
    T.placeItemOnTable(player, item, container, entry.tableObject);
end

function T.watchLocal(character, tableObj, container)
    local entry = {};
    entry.character = character;
    entry.tableObject = tableObj;
    entry.container = container;
    entry.time = getTimestampMs();
    table.insert(T.localPending, entry);
end

function T.onTick()
    if #T.localPending == 0 then
        return;
    end
    local now = getTimestampMs();
    local keep = {};
    for i = 1, #T.localPending do
        local entry = T.localPending[i];
        local item = T.findCorpseItem(entry.container);
        if item then
            T.placeItemOnTable(entry.character, item, entry.container, entry.tableObject);
        elseif now - entry.time < T.LOCAL_TIMEOUT_MS then
            table.insert(keep, entry);
        end
    end
    T.localPending = keep;
end

Events.OnClientCommand.Add(T.onClientCommand);
Events.OnTick.Add(T.onTick);
