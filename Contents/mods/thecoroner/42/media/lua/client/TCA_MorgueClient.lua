require "TCA_Morgue";
require "TimedActions/ISTimedActionQueue";
require "TimedActions/TCA_ToggleMorgueAction";
require "ISUI/ISInventoryPage";
require "BodyDragging/corpseStorageCheck";
require "Definitions/ContainerButtonIcons";

TCA_MorgueClient = TCA_MorgueClient or {};

TCA_MorgueClient.originalAddContainerButton = TCA_MorgueClient.originalAddContainerButton or ISInventoryPage.addContainerButton;
TCA_MorgueClient.originalGetContainerName = TCA_MorgueClient.originalGetContainerName or corpseStorageCheck.getContainerName;

function TCA_MorgueClient.getDrawerOf(container)
    if not container then
        return nil;
    end
    local parent = container:getParent();
    if TCA.Morgue.isDrawer(parent) then
        return parent;
    end
    return nil;
end

function TCA_MorgueClient.addContainerButton(page, container, texture, name, tooltip)
    local obj = TCA_MorgueClient.getDrawerOf(container);
    if obj then
        local title = TCA.Morgue.getDrawerName(obj, container);
        return TCA_MorgueClient.originalAddContainerButton(page, container, ContainerButtonIcons.fridge, title, title);
    end
    return TCA_MorgueClient.originalAddContainerButton(page, container, texture, name, tooltip);
end

function TCA_MorgueClient.getContainerName(container)
    local obj = TCA_MorgueClient.getDrawerOf(container);
    if obj then
        return TCA.Morgue.getDrawerName(obj, container);
    end
    return TCA_MorgueClient.originalGetContainerName(container);
end

ISInventoryPage.addContainerButton = TCA_MorgueClient.addContainerButton;
corpseStorageCheck.getContainerName = TCA_MorgueClient.getContainerName;

function TCA_MorgueClient.findInWorldObjects(worldobjects)
    local seen = {};
    for _, obj in ipairs(worldobjects) do
        if TCA.Morgue.isDrawer(obj) then
            return obj;
        end
        local sq = obj:getSquare();
        if sq and not seen[sq] then
            seen[sq] = true;
            local drawer = TCA.Morgue.findOnSquare(sq);
            if drawer then
                return drawer;
            end
        end
    end
    return nil;
end

function TCA_MorgueClient.onTogglePower(playerObj, obj, turnOn)
    if luautils.walkAdj(playerObj, obj:getSquare(), false) then
        ISTimedActionQueue.add(TCA_ToggleMorgueAction:new(playerObj, obj, turnOn));
    end
end

function TCA_MorgueClient.onFillWorldObjectContextMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player);
    if not playerObj or playerObj:getVehicle() then
        return;
    end
    local obj = TCA_MorgueClient.findInWorldObjects(worldobjects);
    if not obj or obj:getContainerCount() == 0 then
        return;
    end
    if test then
        return true;
    end
    local on = TCA.Morgue.isOn(obj);
    local text = getText("ContextMenu_TCA_MorguePowerOn");
    if on then
        text = getText("ContextMenu_TCA_MorguePowerOff");
    end
    local option = context:addOption(text, playerObj, TCA_MorgueClient.onTogglePower, obj, not on);
    if not TCA.Morgue.isPowered(obj) then
        local tooltip = ISWorldObjectContextMenu.addToolTip();
        tooltip.description = getText("Tooltip_TCA_MorgueNoPower");
        option.toolTip = tooltip;
    end
end

function TCA_MorgueClient.onServerCommand(module, command, args)
    if module ~= "TCA" then
        return;
    end
    if command == "morguePower" then
        TCA.Morgue.onPowerCommand(args);
    end
end

Events.OnFillWorldObjectContextMenu.Add(TCA_MorgueClient.onFillWorldObjectContextMenu);
Events.OnServerCommand.Add(TCA_MorgueClient.onServerCommand);
