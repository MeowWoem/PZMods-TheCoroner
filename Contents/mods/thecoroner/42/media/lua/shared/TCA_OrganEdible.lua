require "TCA_Shared";
require "TCA_Sandbox";
require "TCA_Organs";

TCA = TCA or {};
TCA.OrganEdible = TCA.OrganEdible or {};

local O = TCA.OrganEdible;

O.MODULE = "TCA";
O.PREFIX = "Organ_";
O.KEEP_RECIPES = { AddBaitToChum = true };
O.removed = O.removed or {};
O.applied = nil;

function O.getTypes()
    local types = {};
    for _, organ in ipairs(TCA.Organs.LIST) do
        table.insert(types, O.PREFIX .. organ.id);
    end
    return types;
end

function O.setCantEat(types, cantEat)
    local manager = getScriptManager();
    local value = "false";
    if cantEat then
        value = "true";
    end
    for _, itemType in ipairs(types) do
        local script = manager:getItem(O.MODULE .. "." .. itemType);
        if script then
            script:DoParam("CantEat", value);
        end
    end
end

function O.removeFromEvolvedRecipes(types)
    local recipes = getScriptManager():getAllEvolvedRecipesList();
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i);
        if recipe and not O.KEEP_RECIPES[recipe:getName()] then
            local list = recipe:getItemsList();
            for _, itemType in ipairs(types) do
                local entry = list:get(itemType);
                if entry then
                    local saved = {};
                    saved.recipe = recipe;
                    saved.itemType = itemType;
                    saved.entry = entry;
                    table.insert(O.removed, saved);
                    list:remove(itemType);
                end
            end
        end
    end
end

function O.restoreEvolvedRecipes()
    for _, saved in ipairs(O.removed) do
        saved.recipe:getItemsList():put(saved.itemType, saved.entry);
    end
    O.removed = {};
end

function O.apply()
    local edible = TCA.Sandbox.areOrgansEdible();
    if O.applied == edible then
        return;
    end
    local types = O.getTypes();
    O.setCantEat(types, not edible);
    if edible then
        O.restoreEvolvedRecipes();
    else
        O.removeFromEvolvedRecipes(types);
    end
    O.applied = edible;
end

Events.OnGameStart.Add(O.apply);
Events.OnServerStarted.Add(O.apply);
Events.EveryTenMinutes.Add(O.apply);
