require "TCA_DeathTime";

TCA = TCA or {};
TCA.Morgue = TCA.Morgue or {};

TCA.Morgue.SPRITES = { "location_community_medical_01_66", "location_community_medical_01_67" };
TCA.Morgue.SPRITE_SET = {};
for _, name in ipairs(TCA.Morgue.SPRITES) do
    TCA.Morgue.SPRITE_SET[name] = true;
end

TCA.Morgue.DRAWERS = 2;
TCA.Morgue.CAPACITY = 30;
TCA.Morgue.TYPE_ON = "fridge";
TCA.Morgue.TYPE_OFF = "locker";
TCA.Morgue.CORPSE_CHANCE = 10;
TCA.Morgue.INFECTED_CHANCE = 50;
TCA.Morgue.PRIORITY = 5;

function TCA.Morgue.isDrawer(obj)
    if not obj or not instanceof(obj, "IsoObject") then
        return false;
    end
    local sprite = obj:getSprite();
    if not sprite then
        return false;
    end
    local name = sprite:getName();
    return name ~= nil and TCA.Morgue.SPRITE_SET[name] == true;
end

function TCA.Morgue.findOnSquare(sq)
    if not sq then
        return nil;
    end
    local objects = sq:getObjects();
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i);
        if TCA.Morgue.isDrawer(obj) then
            return obj;
        end
    end
    return nil;
end

function TCA.Morgue.getDrawerObject(container)
    if not container then
        return nil;
    end
    local parent = container:getParent();
    if TCA.Morgue.isDrawer(parent) then
        return parent;
    end
    return nil;
end

function TCA.Morgue.isOn(container)
    return container ~= nil and container:getType() == TCA.Morgue.TYPE_ON;
end

function TCA.Morgue.isAnyOn(obj)
    for i = 0, obj:getContainerCount() - 1 do
        if TCA.Morgue.isOn(obj:getContainerByIndex(i)) then
            return true;
        end
    end
    return false;
end

function TCA.Morgue.isPowered(container)
    return container ~= nil and container:isPowered();
end

function TCA.Morgue.getDrawerKey(obj, container)
    if obj:getContainerIndex(container) > 0 then
        return "IGUI_TCA_MorgueDrawerTop";
    end
    return "IGUI_TCA_MorgueDrawerBottom";
end

function TCA.Morgue.getDrawerName(obj, container)
    local state = "IGUI_TCA_MorgueOff";
    if TCA.Morgue.isOn(container) then
        state = "IGUI_TCA_MorgueOn";
    end
    return getText(TCA.Morgue.getDrawerKey(obj, container)) .. " (" .. getText(state) .. ")";
end

function TCA.Morgue.prepareCorpse(item)
    if not item or not item:isHumanCorpse() then
        return;
    end
    local body = item:loadCorpseFromByteData(nil);
    if not body then
        return;
    end
    body:getModData()["_bloodSplatAmount"] = 0;
    body:getModData()["TCA_Infected"] = ZombRand(100) < TCA.Morgue.INFECTED_CHANCE;
    local deathTime = TCA.DeathTime.inventMorgueDeath();
    TCA.DeathTime.record(body, deathTime, false);
    if TCA.Wounds then
        TCA.Wounds.ensureBody(body);
    end
    if TCA.Cold then
        TCA.Cold.startStay(item, deathTime);
    end
    body:getWornItems():clear();
    body:getAttachedItems():clear();
    local inventory = body:getContainer();
    if inventory then
        inventory:removeAllItems();
    end
    item:storeInByteData(body);
end

function TCA.Morgue.addRandomCorpse(container)
    if ZombRand(100) >= TCA.Morgue.CORPSE_CHANCE then
        return false;
    end
    local itemType = "Base.CorpseMale";
    if ZombRand(2) == 0 then
        itemType = "Base.CorpseFemale";
    end
    TCA.Morgue.prepareCorpse(container:AddItem(itemType));
    return true;
end

function TCA.Morgue.turnOnAtSpawn(obj)
    TCA.Morgue.applyType(obj, true);
    local chunk = obj:getChunk();
    if chunk then
        chunk:addObjectPoweredByGenerator(obj);
    end
    if not isServer() then
        obj:checkHaveElectricity();
    end
end

function TCA.Morgue.fixUnpreparedCorpses(obj)
    local fixed = false;
    for i = 0, obj:getContainerCount() - 1 do
        local items = obj:getContainerByIndex(i):getItems();
        for j = 0, items:size() - 1 do
            local item = items:get(j);
            if item:isHumanCorpse() and item:getByteData() == nil then
                TCA.Morgue.prepareCorpse(item);
                fixed = true;
            end
        end
    end
    if fixed then
        TCA.Morgue.turnOnAtSpawn(obj);
    end
end

function TCA.Morgue.ensureContainers(obj, fillCorpses)
    if obj:getContainerCount() >= TCA.Morgue.DRAWERS then
        return false;
    end
    local sq = obj:getSquare();
    local hasCorpse = false;
    while obj:getContainerCount() < TCA.Morgue.DRAWERS do
        local container = ItemContainer.new(TCA.Morgue.TYPE_OFF, sq, obj);
        container:setCapacity(TCA.Morgue.CAPACITY);
        container:setExplored(true);
        if obj:getContainer() == nil then
            obj:setContainer(container);
        else
            obj:addSecondaryContainer(container);
        end
        if fillCorpses and TCA.Morgue.addRandomCorpse(container) then
            hasCorpse = true;
        end
    end
    if hasCorpse then
        TCA.Morgue.turnOnAtSpawn(obj);
    end
    return true;
end

function TCA.Morgue.applyType(obj, on)
    local containerType = TCA.Morgue.TYPE_OFF;
    if on then
        containerType = TCA.Morgue.TYPE_ON;
    end
    for i = 0, obj:getContainerCount() - 1 do
        local container = obj:getContainerByIndex(i);
        if container then
            container:setType(containerType);
        end
    end
end

function TCA.Morgue.refreshGenerators(obj)
    local chunk = obj:getChunk();
    if chunk then
        if TCA.Morgue.isAnyOn(obj) then
            chunk:addObjectPoweredByGenerator(obj);
        else
            chunk:removeObjectPoweredByGenerator(obj);
        end
    end
    IsoGenerator.updateGenerator(obj:getSquare());
end

function TCA.Morgue.refreshLocal(obj)
    if not isServer() then
        obj:checkHaveElectricity();
        triggerEvent("OnContainerUpdate", obj);
    end
end

function TCA.Morgue.setPowered(obj, on)
    TCA.Morgue.ensureContainers(obj, false);
    if TCA.Cold then
        TCA.Cold.scanDrawer(obj, false);
    end
    TCA.Morgue.applyType(obj, on);
    TCA.Morgue.refreshGenerators(obj);
    if TCA.Cold then
        TCA.Cold.register(obj);
        TCA.Cold.scanDrawer(obj, false);
    end
    TCA.Morgue.refreshLocal(obj);
    if isServer() then
        local sq = obj:getSquare();
        local args = {};
        args.x = sq:getX();
        args.y = sq:getY();
        args.z = sq:getZ();
        args.on = on;
        sendServerCommand("TCA", "morguePower", args);
    end
end

function TCA.Morgue.onPowerCommand(args)
    if not args or not args.x or not args.y or not args.z then
        return;
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z);
    local obj = TCA.Morgue.findOnSquare(sq);
    if not obj then
        return;
    end
    TCA.Morgue.ensureContainers(obj, false);
    TCA.Morgue.applyType(obj, args.on == true);
    TCA.Morgue.refreshLocal(obj);
end

function TCA.Morgue.onNewDrawer(obj)
    if isClient() then
        return;
    end
    TCA.Morgue.ensureContainers(obj, true);
    if TCA.Cold then
        TCA.Cold.register(obj);
    end
end

function TCA.Morgue.onLoadDrawer(obj)
    if isClient() then
        TCA.Morgue.ensureContainers(obj, false);
        return;
    end
    TCA.Morgue.ensureContainers(obj, true);
    TCA.Morgue.fixUnpreparedCorpses(obj);
    TCA.Morgue.applyType(obj, TCA.Morgue.isAnyOn(obj));
    if TCA.Cold then
        TCA.Cold.onDrawerLoaded(obj);
    end
end

function TCA.Morgue.onObjectAdded(obj)
    if not TCA.Morgue.isDrawer(obj) then
        return;
    end
    if TCA.Morgue.ensureContainers(obj, false) then
        TCA.Morgue.refreshLocal(obj);
    end
end

MapObjects.OnNewWithSprite(TCA.Morgue.SPRITES, TCA.Morgue.onNewDrawer, TCA.Morgue.PRIORITY);
MapObjects.OnLoadWithSprite(TCA.Morgue.SPRITES, TCA.Morgue.onLoadDrawer, TCA.Morgue.PRIORITY);
Events.OnObjectAdded.Add(TCA.Morgue.onObjectAdded);
