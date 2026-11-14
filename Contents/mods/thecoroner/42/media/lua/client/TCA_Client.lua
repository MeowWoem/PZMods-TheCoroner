require "TCA_Shared";
require "TCA_Autopsy";
require "TimedActions/ISTimedActionQueue";
require "TimedActions/TCA_ThrowOntoTableAction";
require "TimedActions/TCA_RemoveFromTableAction";
require "TimedActions/TCA_AutopsyAction";
require "TimedActions/TCA_AutopsyResultAction";
require "TimedActions/TCA_HarvestMaggotsAction";
require "TCA_AutopsyUI";
require "TCA_ReferenceUI";
require "TCA_Exam";
require "TCA_Wounds";
require "TCA_Cold";
require "TCA_ExamUI";
require "TimedActions/TCA_ExamAction";
require "TimedActions/TCA_SawBatteryAction";

TCA_Client = TCA_Client or {};

local function addTooltip(option, text)
    option.notAvailable = true;
    local tooltip = ISWorldObjectContextMenu.addToolTip();
    tooltip.description = text;
    option.toolTip = tooltip;
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

TCA_Client.COMMIT_FIELDS = { "segIndex", "segProgress", "accuracy", "paths", "openL", "openR", "tears", "ribs", "accSamples", "organs", "organDamage", "plastron", "attach", "cuts" };

function TCA_Client.commitAutopsy(playerObj, tableObj, result)
    if isClient() then
        local sq = tableObj:getSquare();
        local args = {};
        args.x = sq:getX();
        args.y = sq:getY();
        args.z = sq:getZ();
        for _, key in ipairs(TCA_Client.COMMIT_FIELDS) do
            args[key] = result[key];
        end
        sendClientCommand(playerObj, "TCA", "autopsyCommit", args);
        return;
    end
    TCA_AutopsyResultAction.fromResult(playerObj, tableObj, result):complete();
end

TCA_Client.lockReplies = {};

function TCA_Client.getSquareArgs(tableObj)
    local sq = tableObj:getSquare();
    local args = {};
    args.x = sq:getX();
    args.y = sq:getY();
    args.z = sq:getZ();
    return args;
end

function TCA_Client.getLockKey(x, y, z)
    return string.format("%d,%d,%d", math.floor(x), math.floor(y), math.floor(z));
end

function TCA_Client.requestAutopsyLock(playerObj, tableObj)
    local args = TCA_Client.getSquareArgs(tableObj);
    TCA_Client.lockReplies[TCA_Client.getLockKey(args.x, args.y, args.z)] = nil;
    sendClientCommand(playerObj, "TCA", "autopsyLock", args);
end

function TCA_Client.releaseAutopsyLock(playerObj, tableObj)
    if not tableObj:getSquare() then
        return;
    end
    sendClientCommand(playerObj, "TCA", "autopsyUnlock", TCA_Client.getSquareArgs(tableObj));
end

function TCA_Client.takeLockReply(tableObj)
    local sq = tableObj:getSquare();
    if not sq then
        return false;
    end
    local key = TCA_Client.getLockKey(sq:getX(), sq:getY(), sq:getZ());
    local reply = TCA_Client.lockReplies[key];
    if reply ~= nil then
        TCA_Client.lockReplies[key] = nil;
    end
    return reply;
end

function TCA_Client.onDebugDeathTime(playerObj, body)
    if not body then
        return;
    end
    local D = TCA.DeathTime;
    local hours = D.getHoursSinceDeath(body);
    local known = "IGUI_TCA_DebugDeathInvented";
    if D.isKnown(body) then
        known = "IGUI_TCA_DebugDeathKnown";
    end
    local infected = "IGUI_TCA_DebugNotInfected";
    if TCA.isInfected(body) then
        infected = "IGUI_TCA_DebugInfected";
    end
    local text = getText("IGUI_TCA_DebugDeathTime", string.format("%.1f", hours / 24), string.format("%.1f", hours), getText(known), getText(infected));
    local left = TCA.Cold.getHoursSinceLeft(body);
    local leftText = getText("IGUI_TCA_DebugNever");
    if left ~= nil then
        leftText = string.format("%.1f h", left);
    end
    text = text .. " / " .. getText("IGUI_TCA_DebugCold", string.format("%.1f", TCA.Cold.getColdHours(body)), leftText);
    playerObj:Say(text);
    print("TCA: death " .. tostring(D.get(body)) .. " now " .. tostring(D.now()) .. " vanilla " .. tostring(body:getDeathTime()) .. " " .. text);
end

function TCA_Client.onDebugExamReset(playerObj, body)
    if not body then
        return;
    end
    if isClient() then
        local args = {};
        args.x = body:getX();
        args.y = body:getY();
        args.z = body:getZ();
        sendClientCommand(playerObj, "TCA", "resetExam", args);
        return;
    end
    TCA.Exam.resetResult(body);
end

function TCA_Client.sendExamObservation(playerObj, body, zone, data, observer)
    local args = {};
    args.x = body:getX();
    args.y = body:getY();
    args.z = body:getZ();
    args.zone = zone;
    args.data = data;
    args.observer = observer;
    sendClientCommand(playerObj, "TCA", "examObserve", args);
end

function TCA_Client.onHarvestMaggots(playerObj, body)
    if not body or not body:getSquare() then
        return;
    end
    if luautils.walkAdj(playerObj, body:getSquare(), false) then
        ISTimedActionQueue.add(TCA_HarvestMaggotsAction:new(playerObj, body:getX(), body:getY(), body:getZ()));
    end
end

function TCA_Client.debugWounds(playerObj, body, op, kind, part)
    if not body then
        return;
    end
    if isClient() then
        local args = {};
        args.x = body:getX();
        args.y = body:getY();
        args.z = body:getZ();
        args.op = op;
        args.kind = kind;
        args.part = part;
        sendClientCommand(playerObj, "TCA", "debugWounds", args);
        return;
    end
    TCA.Wounds.debugApply(body, op, kind, part);
end

function TCA_Client.onDebugWoundsRandom(playerObj, body)
    TCA_Client.debugWounds(playerObj, body, "random", nil, nil);
end

function TCA_Client.onDebugWoundsClear(playerObj, body)
    TCA_Client.debugWounds(playerObj, body, "clear", nil, nil);
end

function TCA_Client.onDebugWoundsAdd(playerObj, body, choice)
    TCA_Client.debugWounds(playerObj, body, choice.op, choice.kind, choice.part);
end

function TCA_Client.getPartName(part)
    local bpt = BodyPartType.FromString(part);
    if bpt then
        return BodyPartType.getDisplayName(bpt);
    end
    return part;
end

function TCA_Client.getDebugKindName(kind)
    if kind == "firearm" then
        return getText("IGUI_TCA_Wound_bullet");
    end
    return getText("IGUI_TCA_Wound_" .. kind);
end

function TCA_Client.addDebugKindMenu(menu, playerObj, body, op, kinds, parts)
    for i = 1, #kinds do
        local kindOption = TCA_Client.addBodyOption(menu, body, TCA_Client.getDebugKindName(kinds[i]));
        local partMenu = ISContextMenu:getNew(menu);
        menu:addSubMenu(kindOption, partMenu);
        for j = 1, #parts do
            local choice = {};
            choice.op = op;
            choice.kind = kinds[i];
            choice.part = parts[j];
            TCA_Client.addBodyOption(partMenu, body, TCA_Client.getPartName(parts[j]), playerObj, TCA_Client.onDebugWoundsAdd, body, choice);
        end
    end
end

function TCA_Client.addDebugWoundsMenu(context, playerObj, body)
    local W = TCA.Wounds;
    local root = TCA_Client.addBodyOption(context, body, getText("ContextMenu_TCA_DebugWounds"));
    local menu = ISContextMenu:getNew(context);
    context:addSubMenu(root, menu);
    TCA_Client.addBodyOption(menu, body, getText("ContextMenu_TCA_DebugWoundsShow"), playerObj, TCA_Client.onDebugWounds, body);
    TCA_Client.addBodyOption(menu, body, getText("ContextMenu_TCA_DebugWoundsRandom"), playerObj, TCA_Client.onDebugWoundsRandom, body);
    TCA_Client.addBodyOption(menu, body, getText("ContextMenu_TCA_DebugWoundsClear"), playerObj, TCA_Client.onDebugWoundsClear, body);
    local anteOption = TCA_Client.addBodyOption(menu, body, getText("ContextMenu_TCA_DebugWoundsAddAnte"));
    local anteMenu = ISContextMenu:getNew(menu);
    menu:addSubMenu(anteOption, anteMenu);
    TCA_Client.addDebugKindMenu(anteMenu, playerObj, body, "wound", W.DEBUG_WOUND_KINDS, W.DEBUG_PARTS);
    local causeOption = TCA_Client.addBodyOption(menu, body, getText("ContextMenu_TCA_DebugWoundsCause"));
    local causeMenu = ISContextMenu:getNew(menu);
    menu:addSubMenu(causeOption, causeMenu);
    for i = 1, #W.CAUSES do
        local choice = {};
        choice.op = "cause";
        choice.kind = W.CAUSES[i];
        TCA_Client.addBodyOption(causeMenu, body, getText("IGUI_TCA_Cause_" .. W.CAUSES[i]), playerObj, TCA_Client.onDebugWoundsAdd, body, choice);
    end
    local postOption = TCA_Client.addBodyOption(menu, body, getText("ContextMenu_TCA_DebugWoundsAddPost"));
    local postMenu = ISContextMenu:getNew(menu);
    menu:addSubMenu(postOption, postMenu);
    TCA_Client.addDebugKindMenu(postMenu, playerObj, body, "hit", W.DEBUG_HIT_KINDS, W.DEBUG_HIT_PARTS);
end

function TCA_Client.onDebugWounds(playerObj, body)
    if not body then
        return;
    end
    local lines = TCA.Wounds.describe(body);
    table.insert(lines, 1, "truth=" .. tostring(TCA.Wounds.getTrueCause(body)));
    print("TCA: wounds report");
    for i = 1, #lines do
        print("TCA:   " .. lines[i]);
    end
    playerObj:setHaloNote(table.concat(lines, " / "), 255, 255, 200, 600);
end

function TCA_Client.concludeCause(playerObj, body, cause, observer)
    if not body then
        return;
    end
    if isClient() then
        local args = {};
        args.x = body:getX();
        args.y = body:getY();
        args.z = body:getZ();
        args.cause = cause;
        args.observer = observer;
        sendClientCommand(playerObj, "TCA", "examCause", args);
        return;
    end
    TCA.Wounds.applyCause(playerObj, body, cause, observer);
end

function TCA_Client.onExam(playerObj, body)
    if not body or not body:getSquare() then
        return;
    end
    if luautils.walkAdj(playerObj, body:getSquare(), false) then
        ISTimedActionQueue.add(TCA_ExamAction:new(playerObj, body));
    end
end

function TCA_Client.getSubMenu(context)
    local name = getText("ContextMenu_TCA_Menu");
    local option = context:getOptionFromName(name);
    if option and option.subOption then
        local existing = context:getSubMenu(option.subOption);
        if existing then
            return existing;
        end
    end
    option = context:addOption(name);
    local sub = ISContextMenu:getNew(context);
    context:addSubMenu(option, sub);
    return sub;
end

function TCA_Client.addBodyOption(context, body, name, target, onSelect, param1, param2)
    local option = context:addOption(name, target, onSelect, param1, param2);
    ISWorldObjectContextMenu.initWorldItemHighlightOption(option, body);
    return option;
end

function TCA_Client.addExamOptions(context, playerObj, body, debugMode)
    local exam = TCA_Client.addBodyOption(context, body, getText("ContextMenu_TCA_Exam"), playerObj, TCA_Client.onExam, body);
    if TCA.isTooDark(playerObj) then
        addTooltip(exam, getText("Tooltip_TCA_TooDark"));
    end
    if TCA.Exam.getHarvestCount(body) > 0 then
        TCA_Client.addBodyOption(context, body, getText("ContextMenu_TCA_HarvestMaggots"), playerObj, TCA_Client.onHarvestMaggots, body);
    end
    if debugMode then
        TCA_Client.addBodyOption(context, body, getText("ContextMenu_TCA_DebugDeathTime"), playerObj, TCA_Client.onDebugDeathTime, body);
        TCA_Client.addBodyOption(context, body, getText("ContextMenu_TCA_DebugExamReset"), playerObj, TCA_Client.onDebugExamReset, body);
        TCA_Client.addDebugWoundsMenu(context, playerObj, body);
    end
end

function TCA_Client.findFloorBodies(worldobjects)
    local seen = {};
    local known = {};
    local found = {};
    for _, obj in ipairs(worldobjects) do
        local sq = obj:getSquare();
        if sq and not seen[sq] then
            seen[sq] = true;
            local bodies = sq:getDeadBodys();
            if bodies then
                for i = 0, bodies:size() - 1 do
                    local body = bodies:get(i);
                    if body and not known[body] and not body:isAnimal() and TCA.isBodyOnFloor(body) then
                        known[body] = true;
                        table.insert(found, body);
                    end
                end
            end
        end
    end
    return found;
end

function TCA_Client.findFloorBody(worldobjects)
    return TCA_Client.findFloorBodies(worldobjects)[1];
end

function TCA_Client.onFillFloorBodyMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player);
    if not playerObj or playerObj:getVehicle() or playerObj:isDraggingCorpse() then
        return;
    end
    local bodies = TCA_Client.findFloorBodies(worldobjects);
    if #bodies == 0 then
        return;
    end
    if test then
        return true;
    end
    local sub = TCA_Client.getSubMenu(context);
    local debugMode = TCA_Client.isDebug();
    if #bodies == 1 then
        TCA_Client.addExamOptions(sub, playerObj, bodies[1], debugMode);
        return;
    end
    for i = 1, #bodies do
        local option = sub:addOption(getText("IGUI_ItemCat_Corpse"));
        ISWorldObjectContextMenu.initWorldItemHighlightOption(option, bodies[i]);
        local choice = ISContextMenu:getNew(sub);
        sub:addSubMenu(option, choice);
        TCA_Client.addExamOptions(choice, playerObj, bodies[i], debugMode);
    end
end

function TCA_Client.onSawBattery(playerObj, saw, battery)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, saw);
    if battery then
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, battery);
    end
    ISTimedActionQueue.add(TCA_SawBatteryAction:new(playerObj, saw, battery));
end

function TCA_Client.isChargedBattery(item)
    return item:getCurrentUsesFloat() > 0;
end

function TCA_Client.onFillInventoryMenu(player, context, items)
    local playerObj = getSpecificPlayer(player);
    if not playerObj then
        return;
    end
    local actual = ISInventoryPane.getActualItems(items);
    if #actual ~= 1 then
        return;
    end
    local saw = actual[1];
    if saw:getFullType() ~= TCA.Autopsy.OSCILLATING_SAW and saw:getFullType() ~= TCA.Exam.DIGITAL_THERMOMETER then
        return;
    end
    if saw:getCurrentUsesFloat() > 0 then
        context:addOption(getText("ContextMenu_TCA_SawRemoveBattery"), playerObj, TCA_Client.onSawBattery, saw, nil);
        return;
    end
    local battery = playerObj:getInventory():getFirstTypeEvalRecurse(TCA.Autopsy.BATTERY_TYPE, TCA_Client.isChargedBattery);
    local option = context:addOption(getText("ContextMenu_TCA_SawInsertBattery"), playerObj, TCA_Client.onSawBattery, saw, battery);
    if not battery then
        option.notAvailable = true;
        local tooltip = ISInventoryPaneContextMenu.addToolTip();
        tooltip.description = getText("Tooltip_TCA_NeedBattery");
        option.toolTip = tooltip;
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
    elseif command == "bullets" and args and args.count then
        TCA.Wounds.showBulletHalo(getPlayer(), tonumber(args.count) or 1);
    elseif command == "causeResult" and args then
        TCA.Wounds.showCauseResult(getPlayer(), args.ok == true, tonumber(args.xp) or 0);
    elseif command == "examResult" and args then
        TCA.Exam.showResult(getPlayer(), args.ok == true, tonumber(args.xp) or 0, args.tooWide == true);
    elseif command == "autopsyLock" and args and args.x and args.y and args.z then
        TCA_Client.lockReplies[TCA_Client.getLockKey(args.x, args.y, args.z)] = args.ok == true;
    end
end

TCA_Client.deferred = {};

function TCA_Client.queueNextTick(action)
    table.insert(TCA_Client.deferred, action);
end

TCA_Client.throwAfterGrab = {};
TCA_Client.GRAB_TIMEOUT_MS = 15000;
TCA_Client.DRAG_STATE = "PlayerDraggingCorpse";

function TCA_Client.queueThrowAfterGrab(playerObj, tableObj)
    local entry = {};
    entry.player = playerObj;
    entry.tableObject = tableObj;
    entry.time = getTimestampMs();
    TCA_Client.throwAfterGrab[playerObj:getPlayerNum()] = entry;
end

function TCA_Client.isReadyToThrow(playerObj)
    if not playerObj:isDraggingCorpse() then
        return false;
    end
    if playerObj:getCurrentStateName() ~= TCA_Client.DRAG_STATE then
        return false;
    end
    return not ISTimedActionQueue.isPlayerDoingAction(playerObj);
end

function TCA_Client.checkThrowAfterGrab()
    local now = getTimestampMs();
    for playerNum, entry in pairs(TCA_Client.throwAfterGrab) do
        local playerObj = entry.player;
        if now - entry.time > TCA_Client.GRAB_TIMEOUT_MS or playerObj:isDead() then
            TCA_Client.throwAfterGrab[playerNum] = nil;
        elseif TCA_Client.isReadyToThrow(playerObj) then
            TCA_Client.throwAfterGrab[playerNum] = nil;
            local sq = entry.tableObject:getSquare();
            if sq and luautils.walkAdj(playerObj, sq, true) then
                ISTimedActionQueue.add(TCA_ThrowOntoTableAction:new(playerObj, entry.tableObject));
            end
        end
    end
end

function TCA_Client.onTick()
    TCA_Client.checkThrowAfterGrab();
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

function TCA_Client.onPlaceOnTable(playerObj, tableObj, body)
    if playerObj:isDraggingCorpse() then
        if luautils.walkAdj(playerObj, tableObj:getSquare(), false) then
            ISTimedActionQueue.add(TCA_ThrowOntoTableAction:new(playerObj, tableObj));
        end
        return;
    end
    if not body then
        body = TCA.findBodyNearTable(tableObj, playerObj);
    end
    if not body then
        return;
    end
    if playerObj:isSitOnGround() then
        playerObj:setVariable("forceGetUp", true);
    end
    ISTimedActionQueue.clear(playerObj);
    ISTimedActionQueue.add(ISPathFindAction:pathToGrabCorpse(playerObj, body));
    local primary = playerObj:getPrimaryHandItem();
    local secondary = playerObj:getSecondaryHandItem();
    if primary then
        ISTimedActionQueue.add(ISUnequipAction:new(playerObj, primary, 50));
    end
    if secondary and secondary ~= primary then
        ISTimedActionQueue.add(ISUnequipAction:new(playerObj, secondary, 50));
    end
    ISTimedActionQueue.add(ISGrabCorpseAction:new(playerObj, body));
    TCA_Client.queueThrowAfterGrab(playerObj, tableObj);
end

function TCA_Client.getPlaceBlockReason(tableObj, occupied)
    if not TCA.isLongTable(tableObj) then
        return getText("Tooltip_TCA_TableTooSmall");
    elseif occupied then
        return getText("Tooltip_TCA_TableOccupied");
    end
    local clutter = TCA.getTableClutter(tableObj);
    if clutter == "object" then
        return getText("Tooltip_TCA_TableClutterObject");
    elseif clutter == "items" then
        return getText("Tooltip_TCA_TableClutterItems");
    end
    return nil;
end

function TCA_Client.addPlaceOptions(sub, playerObj, tableObj, occupied, dragging)
    local reason = TCA_Client.getPlaceBlockReason(tableObj, occupied);
    local name = getText("ContextMenu_TCA_PlaceOnTable");
    if dragging then
        local option = sub:addOption(name, playerObj, TCA_Client.onPlaceOnTable, tableObj, nil);
        if reason then
            addTooltip(option, reason);
        end
        return;
    end
    local bodies = TCA.findBodiesNearTable(tableObj);
    if #bodies == 0 then
        return;
    end
    if #bodies == 1 then
        local option = sub:addOption(name, playerObj, TCA_Client.onPlaceOnTable, tableObj, bodies[1]);
        ISWorldObjectContextMenu.initWorldItemHighlightOption(option, bodies[1]);
        if reason then
            addTooltip(option, reason);
        end
        return;
    end
    local parent = sub:addOption(name);
    local choice = ISContextMenu:getNew(sub);
    sub:addSubMenu(parent, choice);
    for i = 1, #bodies do
        local option = choice:addOption(getText("IGUI_ItemCat_Corpse"), playerObj, TCA_Client.onPlaceOnTable, tableObj, bodies[i]);
        ISWorldObjectContextMenu.initWorldItemHighlightOption(option, bodies[i]);
        if reason then
            addTooltip(option, reason);
        end
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

    local sub = TCA_Client.getSubMenu(context);
    if canUseBody then
        local autopsy = sub:addOption(getText("ContextMenu_TCA_Autopsy"), playerObj, TCA_Client.onAutopsy, tableObj);
        local clothing = TCA.Autopsy.getBlockingClothing(body);
        local stage = TCA.Autopsy.getStage(body);
        if stage == "done" then
            addTooltip(autopsy, getText("Tooltip_TCA_AlreadyAutopsied"));
        elseif clothing then
            addTooltip(autopsy, getText("Tooltip_TCA_MustUndress", clothing:getDisplayName()));
        elseif not TCA.Autopsy.hasToolForStage(playerObj, stage) then
            addTooltip(autopsy, TCA_Client.getMissingToolText(stage));
        elseif TCA.isTooDark(playerObj) then
            addTooltip(autopsy, getText("Tooltip_TCA_TooDark"));
        end
        sub:addOption(getText("ContextMenu_TCA_RemoveFromTable"), playerObj, TCA_Client.onRemoveFromTable, tableObj);
        TCA_Client.addExamOptions(sub, playerObj, body, debugMode);
        if debugMode then
            sub:addOption(getText("ContextMenu_TCA_DebugReset"), playerObj, TCA_Client.onDebugReset, tableObj);
        end
    end

    if canPlace then
        TCA_Client.addPlaceOptions(sub, playerObj, tableObj, occupied, dragging);
    end

    if debugMode then
        sub:addOption(getText("ContextMenu_TCA_DebugReference"), playerObj, TCA_Client.onDebugReference, tableObj);
    end

end

Events.OnFillWorldObjectContextMenu.Add(TCA_Client.onFillWorldObjectContextMenu);
Events.OnFillWorldObjectContextMenu.Add(TCA_Client.onFillFloorBodyMenu);
Events.OnFillInventoryObjectContextMenu.Add(TCA_Client.onFillInventoryMenu);
Events.OnTick.Add(TCA_Client.onTick);
Events.OnServerCommand.Add(TCA_Client.onServerCommand);
