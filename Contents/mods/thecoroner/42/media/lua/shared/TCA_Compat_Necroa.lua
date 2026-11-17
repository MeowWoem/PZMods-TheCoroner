require "TCA_Wounds";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.Necroa = TCA.Compat.Necroa or {};

local X = TCA.Compat.Necroa;

X.MOD_ID = "Necroa";
X.MODULE = "FZ3";
X.PROBE_ITEM = "FZ3.FZ3";

function X.isActive()
    if not TCA.Wounds.isModActivated(X.MOD_ID) then
        return false;
    end
    return ScriptManager.instance:getItem(X.PROBE_ITEM) ~= nil;
end

function X.keepWornItem(item)
    return item ~= nil and item:getModule() == X.MODULE;
end

TCA.Wounds.registerProvider({
    id = X.MOD_ID,
    isActive = X.isActive,
    keepWornItem = X.keepWornItem,
});
