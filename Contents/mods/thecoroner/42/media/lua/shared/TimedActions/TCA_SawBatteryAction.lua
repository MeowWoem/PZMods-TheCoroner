require "TimedActions/ISBaseTimedAction";
require "TCA_Autopsy";

TCA_SawBatteryAction = ISBaseTimedAction:derive("TCA_SawBatteryAction");

function TCA_SawBatteryAction:isValid()
    local inv = self.character:getInventory();
    if not inv:contains(self.saw) then
        return false;
    end
    if self.battery then
        return inv:contains(self.battery) and self.saw:getCurrentUsesFloat() <= 0;
    end
    return self.saw:getCurrentUsesFloat() > 0;
end

function TCA_SawBatteryAction:waitToStart()
    return false;
end

function TCA_SawBatteryAction:update()
    self.saw:setJobDelta(self:getJobDelta());
    self.character:setMetabolicTarget(Metabolics.LightDomestic);
end

function TCA_SawBatteryAction:start()
    self.saw:setJobType(self.jobText);
    self.saw:setJobDelta(0.0);
    self:setActionAnim("Craft");
end

function TCA_SawBatteryAction:stop()
    self.saw:setJobDelta(0.0);
    ISBaseTimedAction.stop(self);
end

function TCA_SawBatteryAction:perform()
    self.saw:setJobDelta(0.0);
    ISBaseTimedAction.perform(self);
end

function TCA_SawBatteryAction:complete()
    local inv = self.character:getInventory();
    if self.battery then
        if not inv:contains(self.battery) or self.saw:getCurrentUsesFloat() > 0 then
            return false;
        end
        local charge = self.battery:getCurrentUsesFloat();
        inv:Remove(self.battery);
        sendRemoveItemFromContainer(inv, self.battery);
        self.saw:setCurrentUsesFloat(charge);
        self.saw:syncItemFields();
        return true;
    end
    local charge = self.saw:getCurrentUsesFloat();
    if charge <= 0 then
        return false;
    end
    local battery = instanceItem(TCA.Autopsy.BATTERY_TYPE);
    if battery then
        battery:setCurrentUsesFloat(charge);
        inv:AddItem(battery);
        sendAddItemToContainer(inv, battery);
    end
    self.saw:setCurrentUsesFloat(0);
    self.saw:syncItemFields();
    return true;
end

function TCA_SawBatteryAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 60;
end

function TCA_SawBatteryAction:new(character, saw, battery)
    local o = ISBaseTimedAction.new(self, character);
    o.saw = saw;
    o.battery = battery;
    o.jobText = getText("ContextMenu_TCA_SawRemoveBattery");
    if battery then
        o.jobText = getText("ContextMenu_TCA_SawInsertBattery");
    end
    o.stopOnWalk = false;
    o.stopOnRun = true;
    o.maxTime = o:getDuration();
    return o;
end
