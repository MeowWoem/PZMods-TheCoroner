require "TCA_Shared";
require "TCA_Autopsy";
require "TimedActions/ISTimedActionQueue";
require "TimedActions/TCA_LetGoForTableAction";
require "TimedActions/TCA_PlaceOnTableAction";
require "TimedActions/TCA_RemoveFromTableAction";
require "TimedActions/TCA_AutopsyAction";
require "TimedActions/TCA_AutopsyResultAction";
require "TCA_AutopsyUI";
require "TCA_ReferenceUI";

TCA_Client = TCA_Client or {};

TCA_Client.pending = {};
TCA_Client.PENDING_TIMEOUT_MS = 5000;

function TCA_Client.waitForDroppedBody(playerObj, tableObj)
    local entry = {};
    entry.player = playerObj;
    entry.tableObject = tableObj;
    entry.time = getTimestampMs();
    TCA_Client.pending[playerObj:getPlayerNum()] = entry;
end

function TCA_Client.onDeadBodySpawn(body)
    if not body or body:isAnimal() then
        return;
    end
    local now = getTimestampMs();
    for playerNum, entry in pairs(TCA_Client.pending) do
        if now - entry.time > TCA_Client.PENDING_TIMEOUT_MS then
            TCA_Client.pending[playerNum] = nil;
        else
            local dx = body:getX() - entry.player:getX();
            local dy = body:getY() - entry.player:getY();
            if dx * dx + dy * dy <= 9 then
                TCA_Client.pending[playerNum] = nil;
                ISTimedActionQueue.add(TCA_PlaceOnTableAction:new(entry.player, entry.tableObject));
                return;
            end
        end
    end
end

function TCA_Client.requestCut(playerObj)
    if isClient() then
        sendClientCommand(playerObj, "TCA", "cut", {});
    else
        TCA.Autopsy.applyCut(playerObj);
    end
end

function TCA_Client.onDebugReset(playerObj, tableObj)
    if isClient() then
        local sq = tableObj:getSquare();
        local args = {};
        args.x = sq:getX();
        args.y = sq:getY();
        args.z = sq:getZ();
        sendClientCommand(playerObj, "TCA", "resetAutopsy", args);
        return;
    end
    local body = TCA.findBodyOnTable(tableObj);
    if body then
        TCA.Autopsy.resetBody(body);
    end
end

function TCA_Client.debugSetStep(playerObj, tableObj, pos)
    if isClient() then
        local sq = tableObj:getSquare();
        local args = {};
        args.x = sq:getX();
        args.y = sq:getY();
        args.z = sq:getZ();
        args.pos = pos;
        sendClientCommand(playerObj, "TCA", "debugStep", args);
        return;
    end
    local body = TCA.findBodyOnTable(tableObj);
    if body then
        TCA.Autopsy.applyDebugPosition(body, pos);
    end
end

function TCA_Client.onDebugReference(playerObj, tableObj)
    TCA_ReferenceUI.open(tableObj);
end

function TCA_Client.isDebug()
    return TCA.DEBUG or isDebugEnabled();
end

function TCA_Client.onServerCommand(module, command, args)
    if module ~= "TCA" then
        return;
    end
    if command == "xp" and args and args.xp then
        TCA.Autopsy.showXpHalo(getPlayer(), args.xp);
    end
end

TCA_Client.deferred = {};

function TCA_Client.queueNextTick(action)
    table.insert(TCA_Client.deferred, action);
end

function TCA_Client.onTick()
    if #TCA_Client.deferred == 0 then
        return;
    end
    local list = TCA_Client.deferred;
    TCA_Client.deferred = {};
    for _, action in ipairs(list) do
        ISTimedActionQueue.add(action);
    end
end

function TCA_Client.findTableInWorldObjects(worldobjects)
    local seen = {};
    for _, obj in ipairs(worldobjects) do
        if TCA.isTableObject(obj) then
            return obj;
        end
        local sq = obj:getSquare();
        if sq and not seen[sq] then
            seen[sq] = true;
            local tableObj = TCA.findTableOnSquare(sq);
            if tableObj then
                return tableObj;
            end
        end
    end
    return nil;
end

function TCA_Client.onPlaceOnTable(playerObj, tableObj)
    if playerObj:isDraggingCorpse() then
        if luautils.walkAdj(playerObj, tableObj:getSquare(), false) then
            ISTimedActionQueue.add(TCA_LetGoForTableAction:new(playerObj, tableObj));
        end
        return;
    end
    if luautils.walkAdj(playerObj, tableObj:getSquare(), false) then
        ISTimedActionQueue.add(TCA_PlaceOnTableAction:new(playerObj, tableObj));
    end
end

function TCA_Client.onRemoveFromTable(playerObj, tableObj)
    if luautils.walkAdj(playerObj, tableObj:getSquare(), false) then
        ISTimedActionQueue.add(TCA_RemoveFromTableAction:new(playerObj, tableObj));
    end
end

function TCA_Client.onAutopsy(playerObj, tableObj)
    if luautils.walkAdj(playerObj, tableObj:getSquare(), false) then
        ISTimedActionQueue.add(TCA_AutopsyAction:new(playerObj, tableObj));
    end
end

function TCA_Client.getMissingToolText(stage)
    if stage == "open" then
        return getText("Tooltip_TCA_NeedForceps");
    elseif stage == "ribs" then
        return getText("Tooltip_TCA_NeedRibTool");
    end
    return getText("Tooltip_TCA_NeedScalpel");
end

local function addTooltip(option, text)
    option.notAvailable = true;
    local tooltip = ISWorldObjectContextMenu.addToolTip();
    tooltip.description = text;
    option.toolTip = tooltip;
end

function TCA_Client.onFillWorldObjectContextMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player);
    if not playerObj or playerObj:getVehicle() then
        return;
    end

    local tableObj = TCA_Client.findTableInWorldObjects(worldobjects);
    if not tableObj then
        return;
    end

    TCA.debugTable(tableObj);

    local dragging = playerObj:isDraggingCorpse();
    local body = TCA.findBodyOnTable(tableObj);
    local occupied = body ~= nil;
    local canPlace = dragging or TCA.findBodyNearTable(tableObj, playerObj) ~= nil;
    local canUseBody = occupied and not dragging;
    local debugMode = TCA_Client.isDebug();
    if not canPlace and not canUseBody and not debugMode then
        return;
    end

    if test then
        return true;
    end

    if canUseBody then
        local autopsy = context:addOption(getText("ContextMenu_TCA_Autopsy"), playerObj, TCA_Client.onAutopsy, tableObj);
        local clothing = TCA.Autopsy.getBlockingClothing(body);
        local stage = TCA.Autopsy.getStage(body);
        if stage == "done" then
            addTooltip(autopsy, getText("Tooltip_TCA_AlreadyAutopsied"));
        elseif clothing then
            addTooltip(autopsy, getText("Tooltip_TCA_MustUndress", clothing:getDisplayName()));
        elseif not TCA.Autopsy.hasToolForStage(playerObj, stage) then
            addTooltip(autopsy, TCA_Client.getMissingToolText(stage));
        end
        context:addOption(getText("ContextMenu_TCA_RemoveFromTable"), playerObj, TCA_Client.onRemoveFromTable, tableObj);
        if debugMode then
            context:addOption(getText("ContextMenu_TCA_DebugReset"), playerObj, TCA_Client.onDebugReset, tableObj);
        end
    end

    if debugMode then
        context:addOption(getText("ContextMenu_TCA_DebugReference"), playerObj, TCA_Client.onDebugReference, tableObj);
    end

    if canPlace then
        local option = context:addOption(getText("ContextMenu_TCA_PlaceOnTable"), playerObj, TCA_Client.onPlaceOnTable, tableObj);
        if not TCA.isLongTable(tableObj) then
            addTooltip(option, getText("Tooltip_TCA_TableTooSmall"));
        elseif occupied then
            addTooltip(option, getText("Tooltip_TCA_TableOccupied"));
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(TCA_Client.onFillWorldObjectContextMenu);
Events.OnDeadBodySpawn.Add(TCA_Client.onDeadBodySpawn);
Events.OnTick.Add(TCA_Client.onTick);
Events.OnServerCommand.Add(TCA_Client.onServerCommand);
