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
    if TCA.Exam.storeObservation(body, TCA.Exam.getObserverKey(player), args.zone, args.data) then
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
    elseif command == "autopsyCommit" then
        TCA_Server.onAutopsyCommitCommand(player, args);
    elseif command == "resetExam" then
        TCA_Server.onResetExamCommand(player, args);
    elseif command == "examObserve" then
        TCA_Server.onExamObserveCommand(player, args);
    elseif command == "debugWounds" then
        TCA_Server.onDebugWoundsCommand(player, args);
    end
end

Events.OnClientCommand.Add(TCA_Server.onClientCommand);
