require "TCA_Thermometer";
require "TimedActions/TCA_TakeTemperatureAction";
require "ISUI/ISModalDialog";

TCA_ThermometerClient = TCA_ThermometerClient or {};

local C = TCA_ThermometerClient;

function C.addMissingTooltip(option)
    option.notAvailable = true;
    local tooltip = ISWorldObjectContextMenu.addToolTip();
    tooltip.description = getText("Tooltip_TCA_NeedThermometer");
    option.toolTip = tooltip;
end

function C.startOnSelf(playerObj)
    ISTimedActionQueue.add(TCA_TakeTemperatureAction:new(playerObj, playerObj));
end

function C.startOnOther(playerObj, target)
    if not target or target:isDead() or not target:getCurrentSquare() then
        return;
    end
    if luautils.walkAdj(playerObj, target:getCurrentSquare()) then
        ISTimedActionQueue.add(TCA_TakeTemperatureAction:new(playerObj, target));
    end
end

function C.onTakeOther(worldobjects, playerObj, target)
    if not isClient() then
        C.startOnOther(playerObj, target);
        return;
    end
    local args = {};
    args.target = target:getOnlineID();
    sendClientCommand(playerObj, "TCA", "tempRequest", args);
end

function C.onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then
        return;
    end
    local playerObj = getSpecificPlayer(player);
    if not playerObj or playerObj:isDead() then
        return;
    end
    local fetch = ISWorldObjectContextMenu.fetchVars;
    local target = fetch and fetch.clickedPlayer;
    if not target or target == playerObj or target:isDead() or target:isAnimal() then
        return;
    end
    local option = context:addOption(getText("ContextMenu_TCA_TakeTempOf", target:getDisguisedDisplayName()), worldobjects, C.onTakeOther, playerObj, target);
    if not TCA.Thermometer.findThermometer(playerObj) then
        C.addMissingTooltip(option);
    end
end

function C.onFillInventoryMenu(player, context, items)
    local playerObj = getSpecificPlayer(player);
    if not playerObj then
        return;
    end
    local actual = ISInventoryPane.getActualItems(items);
    if #actual ~= 1 then
        return;
    end
    local item = actual[1];
    local isThermometer = false;
    for _, itemType in ipairs(TCA.Exam.THERMOMETER_TYPES) do
        if item:getFullType() == itemType then
            isThermometer = true;
        end
    end
    if not isThermometer or not playerObj:getInventory():containsRecursive(item) then
        return;
    end
    context:addOption(getText("ContextMenu_TCA_TakeOwnTemp"), playerObj, C.startOnSelf);
end

function C.onAnswerRequest(target, button)
    local args = {};
    args.requester = button.parent.requesterId;
    args.ok = button.internal == "YES";
    sendClientCommand(getPlayer(), "TCA", "tempAnswer", args);
end

function C.receiveRequest(args)
    local requester = getPlayerByOnlineID(args.requester);
    if not requester then
        return;
    end
    local text = getText("IGUI_TCA_TempRequest", requester:getDisguisedDisplayName());
    local modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 175, getCore():getScreenHeight() / 2 - 75, 350, 150, text, true, nil, C.onAnswerRequest);
    modal:initialise();
    modal:addToUIManager();
    modal.requesterId = args.requester;
    modal.moveWithMouse = true;
    modal:bringToTop();
end

function C.receiveAnswer(args)
    local playerObj = getPlayer();
    local target = getPlayerByOnlineID(args.target);
    if not playerObj or not target then
        return;
    end
    if args.ok then
        C.startOnOther(playerObj, target);
    else
        HaloTextHelper.addBadText(playerObj, getText("IGUI_TCA_TempRefused", target:getDisguisedDisplayName()));
    end
end

function C.onServerCommand(module, command, args)
    if module ~= "TCA" or not args then
        return;
    end
    if command == "tempRequest" then
        C.receiveRequest(args);
    elseif command == "tempAnswer" then
        C.receiveAnswer(args);
    elseif command == "tempResult" then
        local celsius = tonumber(args.c);
        if celsius then
            TCA.Thermometer.showResult(getPlayer(), celsius, args.target, args.by);
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(C.onFillWorldObjectContextMenu);
Events.OnFillInventoryObjectContextMenu.Add(C.onFillInventoryMenu);
Events.OnServerCommand.Add(C.onServerCommand);
