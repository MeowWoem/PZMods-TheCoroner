require "TCA_Shared";
require "TCA_Autopsy";

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

function TCA_Server.onClientCommand(module, command, player, args)
    if module ~= "TCA" then
        return;
    end
    if command == "cut" then
        TCA_Server.onCutCommand(player);
    elseif command == "resetAutopsy" then
        TCA_Server.onResetCommand(player, args);
    end
end

Events.OnClientCommand.Add(TCA_Server.onClientCommand);
