require "TCA_Wounds";
require "TCA_Shared";
require "TCA_Autopsy";
require "TCA_Exam";
require "TimedActions/TCA_AutopsyResultAction";

TCA_Server = TCA_Server or {};

function TCA_Server.onCutCommand(player)
    TCA.Autopsy.applyCut(player);
end

function TCA_Server.onResetCommand(player, args)
    if not player:getRole():hasCapability(Capability.AddItem) then
        return;
    end
    if not args or not args.x or not args.y or not args.z then
        return;
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z);
    local tableObj = TCA.findTableOnSquare(sq);
    if not tableObj then
        return;
    end
    local body = TCA.findBodyOnTable(tableObj);
    if body then
        TCA.Autopsy.resetBody(body);
    end
end

function TCA_Server.onDebugStepCommand(player, args)
    if not player:getRole():hasCapability(Capability.AddItem) then
        return;
    end
    if not args or not args.x or not args.y or not args.z or not args.pos then
        return;
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z);
    local tableObj = TCA.findTableOnSquare(sq);
    if not tableObj then
        return;
    end
    local body = TCA.findBodyOnTable(tableObj);
    if body then
        TCA.Autopsy.applyDebugPosition(body, args.pos);
    end
end

TCA_Server.locks = {};
TCA_Server.LOCK_RANGE = 5;

function TCA_Server.findOnlinePlayer(name)
    local players = getOnlinePlayers();
    if not players then
        return nil;
    end
    for i = 0, players:size() - 1 do
        local p = players:get(i);
        if p and p:getUsername() == name then
            return p;
        end
    end
    return nil;
end

function TCA_Server.getBodyLockKey(args)
    if not args or not args.x or not args.y or not args.z then
        return nil;
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z);
    local tableObj = TCA.findTableOnSquare(sq);
    if not tableObj then
        return nil;
    end
    local body = TCA.findBodyOnTable(tableObj);
    if not body or not body:getSquare() then
        return nil;
    end
    local bsq = body:getSquare();
    return string.format("%d,%d,%d", bsq:getX(), bsq:getY(), bsq:getZ()), bsq;
end

function TCA_Server.isLockActive(holder, bsq)
    local p = TCA_Server.findOnlinePlayer(holder);
    if not p or p:isDead() then
        return false;
    end
    if math.abs(p:getX() - (bsq:getX() + 0.5)) > TCA_Server.LOCK_RANGE or math.abs(p:getY() - (bsq:getY() + 0.5)) > TCA_Server.LOCK_RANGE then
        return false;
    end
    return true;
end

function TCA_Server.isLockedByOther(player, key, bsq)
    local holder = TCA_Server.locks[key];
    if not holder or holder == player:getUsername() then
        return false;
    end
    if TCA_Server.isLockActive(holder, bsq) then
        return true;
    end
    TCA_Server.locks[key] = nil;
    return false;
end

function TCA_Server.onAutopsyLockCommand(player, args)
    local key, bsq = TCA_Server.getBodyLockKey(args);
    local ok = false;
    if key and not TCA_Server.isLockedByOther(player, key, bsq) then
        TCA_Server.locks[key] = player:getUsername();
        ok = true;
    end
    local reply = {};
    reply.x = args and args.x;
    reply.y = args and args.y;
    reply.z = args and args.z;
    reply.ok = ok;
    sendServerCommand(player, "TCA", "autopsyLock", reply);
end

function TCA_Server.onAutopsyUnlockCommand(player, args)
    local key = TCA_Server.getBodyLockKey(args);
    if key and TCA_Server.locks[key] == player:getUsername() then
        TCA_Server.locks[key] = nil;
    end
end

function TCA_Server.onAutopsyCommitCommand(player, args)
    if not args or not args.x or not args.y or not args.z then
        return;
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z);
    local tableObj = TCA.findTableOnSquare(sq);
    if not tableObj then
        return;
    end
    if math.abs(player:getX() - (args.x + 0.5)) > 4 or math.abs(player:getY() - (args.y + 0.5)) > 4 then
        return;
    end
    local key, bsq = TCA_Server.getBodyLockKey(args);
    if key and TCA_Server.isLockedByOther(player, key, bsq) then
        return;
    end
    TCA_AutopsyResultAction.fromResult(player, tableObj, args):complete();
end

function TCA_Server.onResetExamCommand(player, args)
    if not player:getRole():hasCapability(Capability.AddItem) then
        return;
    end
    if not args then
        return;
    end
    local body = TCA.findBodyAt(args.x, args.y, args.z);
    if body then
        TCA.Exam.resetResult(body);
        body:transmitModData();
    end
end

function TCA_Server.onExamObserveCommand(player, args)
    if not args or not TCA.Exam.isValidObservation(args.zone, args.data) then
        return;
    end
    if math.abs(player:getX() - args.x) > 4 or math.abs(player:getY() - args.y) > 4 then
        return;
    end
    local body = TCA.findBodyAt(args.x, args.y, args.z);
    if not body then
        return;
    end
    if TCA.Exam.storeObservation(body, TCA.Exam.getObserverKey(player, args.observer), args.zone, args.data) then
        body:transmitModData();
    end
end

function TCA_Server.onDebugWoundsCommand(player, args)
    if not player:getRole():hasCapability(Capability.AddItem) or not args then
        return;
    end
    local body = TCA.findBodyAt(args.x, args.y, args.z);
    if body and TCA.Wounds.debugApply(body, args.op, args.kind, args.part) then
        body:transmitModData();
    end
end

function TCA_Server.onExamCauseCommand(player, args)
    if not args or not TCA.Wounds.isCause(args.cause) then
        return;
    end
    if math.abs(player:getX() - args.x) > 4 or math.abs(player:getY() - args.y) > 4 then
        return;
    end
    local body = TCA.findBodyAt(args.x, args.y, args.z);
    if body then
        TCA.Wounds.applyCause(player, body, args.cause, args.observer);
    end
end

function TCA_Server.onClientCommand(module, command, player, args)
    if module ~= "TCA" then
        return;
    end
    if command == "cut" then
        TCA_Server.onCutCommand(player);
    elseif command == "resetAutopsy" then
        TCA_Server.onResetCommand(player, args);
    elseif command == "debugStep" then
        TCA_Server.onDebugStepCommand(player, args);
    elseif command == "autopsyLock" then
        TCA_Server.onAutopsyLockCommand(player, args);
    elseif command == "autopsyUnlock" then
        TCA_Server.onAutopsyUnlockCommand(player, args);
    elseif command == "autopsyCommit" then
        TCA_Server.onAutopsyCommitCommand(player, args);
    elseif command == "resetExam" then
        TCA_Server.onResetExamCommand(player, args);
    elseif command == "examObserve" then
        TCA_Server.onExamObserveCommand(player, args);
    elseif command == "examCause" then
        TCA_Server.onExamCauseCommand(player, args);
    elseif command == "debugWounds" then
        TCA_Server.onDebugWoundsCommand(player, args);
    end
end

Events.OnClientCommand.Add(TCA_Server.onClientCommand);
