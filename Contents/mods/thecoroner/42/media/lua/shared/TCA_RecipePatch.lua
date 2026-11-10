TCA = TCA or {};
TCA.RecipePatch = TCA.RecipePatch or {};

local P = TCA.RecipePatch;

P.SOURCE_ITEM = "Base.AnimalBone";
P.ADDED_ITEM = "TCA.HumanBone";

P.MAPPERS = {
    MakeBoneClub = { mapper = "ClubMapper", result = "Base.BoneClub" },
};

function P.patchMapper(recipe)
    local def = P.MAPPERS[recipe:getName()];
    if not def then
        return;
    end
    local body = "{ itemMapper " .. def.mapper .. " { " .. def.result .. " = " .. P.ADDED_ITEM .. ", } }";
    local ok, err = pcall(recipe.Load, recipe, recipe:getName(), body);
    if not ok then
        print("TCA: failed to patch mapper " .. def.mapper .. " of " .. recipe:getName() .. ": " .. tostring(err));
    end
end

function P.patchRecipe(recipe)
    local inputs = recipe:getInputs();
    if not inputs then
        return 0;
    end
    local patched = 0;
    for i = 0, inputs:size() - 1 do
        local items = inputs:get(i):getItems();
        if items and items:contains(P.SOURCE_ITEM) and not items:contains(P.ADDED_ITEM) then
            items:add(P.ADDED_ITEM);
            patched = patched + 1;
        end
    end
    if patched > 0 then
        P.patchMapper(recipe);
    end
    return patched;
end

function P.apply()
    local recipes = ScriptManager.instance:getAllCraftRecipes();
    if not recipes then
        return;
    end
    local count = 0;
    for i = 0, recipes:size() - 1 do
        if P.patchRecipe(recipes:get(i)) > 0 then
            count = count + 1;
        end
    end
    print("TCA: human bone added to " .. count .. " craft recipes");
end

Events.OnGameBoot.Add(P.apply);
