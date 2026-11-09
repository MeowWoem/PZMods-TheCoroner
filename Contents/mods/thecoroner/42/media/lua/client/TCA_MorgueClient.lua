require "TCA_Morgue";
require "TimedActions/ISTimedActionQueue";
require "TimedActions/TCA_ToggleMorgueAction";
require "ISUI/ISInventoryPage";
require "ISUI/LootWindow/ISLootWindowObjectControlHandler";
require "ISUI/LootWindow/ISLootWindowContainerControls";
require "BodyDragging/corpseStorageCheck";
require "Definitions/ContainerButtonIcons";

TCA_MorgueClient = TCA_MorgueClient or {};

TCA_MorgueClient.originalAddContainerButton = TCA_MorgueClient.originalAddContainerButton or ISInventoryPage.addContainerButton;
TCA_MorgueClient.originalGetContainerName = TCA_MorgueClient.originalGetContainerName or corpseStorageCheck.getContainerName;

function TCA_MorgueClient.addContainerButton(page, container, texture, name, tooltip)
    local obj = TCA.Morgue.getDrawerObject(container);
    if obj then
        local title = TCA.Morgue.getDrawerName(obj, container);
        return TCA_MorgueClient.originalAddContainerButton(page, container, ContainerButtonIcons.fridge, title, title);
    end
    return TCA_MorgueClient.originalAddContainerButton(page, container, texture, name, tooltip);
end

function TCA_MorgueClient.getContainerName(container)
    local obj = TCA.Morgue.getDrawerObject(container);
    if obj then
        return TCA.Morgue.getDrawerName(obj, container);
    end
    return TCA_MorgueClient.originalGetContainerName(container);
end

ISInventoryPage.addContainerButton = TCA_MorgueClient.addContainerButton;
corpseStorageCheck.getContainerName = TCA_MorgueClient.getContainerName;

function TCA_MorgueClient.togglePower(playerObj, obj, turnOn)
    if luautils.walkAdj(playerObj, obj:getSquare(), false) then
        ISTimedActionQueue.add(TCA_ToggleMorgueAction:new(playerObj, obj, turnOn));
    end
end

TCA_MorgueToggleHandler = ISLootWindowObjectControlHandler:derive("TCA_MorgueToggleHandler");

function TCA_MorgueToggleHandler:shouldBeVisible()
    return self.container ~= nil and TCA.Morgue.getDrawerObject(self.container) == self.object;
end

function TCA_MorgueToggleHandler:getTitle()
    if TCA.Morgue.isAnyOn(self.object) then
        return getText("ContextMenu_Turn_Off");
    end
    return getText("ContextMenu_Turn_On");
end

function TCA_MorgueToggleHandler:getControl()
    self.control = self:getButtonControl(self:getTitle());
    if TCA.Morgue.isPowered(self.container) then
        self.control.tooltip = nil;
    else
        self.control.tooltip = getText("Tooltip_TCA_MorgueNoPower");
    end
    return self.control;
end

function TCA_MorgueToggleHandler:handleJoypadContextMenu(context)
    local option = self:addJoypadContextMenuOption(context, self:getTitle());
    option.iconTexture = ContainerButtonIcons.fridge;
end

function TCA_MorgueToggleHandler:perform()
    TCA_MorgueClient.togglePower(self.playerObj, self.object, not TCA.Morgue.isAnyOn(self.object));
end

function TCA_MorgueToggleHandler:new()
    local o = ISLootWindowObjectControlHandler.new(self);
    o.altColor = true;
    return o;
end

ISLootWindowContainerControls.AddHandler(TCA_MorgueToggleHandler, true);

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

function TCA_MorgueClient.addPowerOption(context, playerObj, obj)
    local on = TCA.Morgue.isAnyOn(obj);
    local text = getText("ContextMenu_TCA_MorguePowerOn");
    if on then
        text = getText("ContextMenu_TCA_MorguePowerOff");
    end
    local option = context:addOption(text, playerObj, TCA_MorgueClient.togglePower, obj, not on);
    if not TCA.Morgue.isPowered(obj:getContainerByIndex(0)) then
        local tooltip = ISWorldObjectContextMenu.addToolTip();
        tooltip.description = getText("Tooltip_TCA_MorgueNoPower");
        option.toolTip = tooltip;
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
    TCA_MorgueClient.addPowerOption(context, playerObj, obj);
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
