require "TCA_Compat_CasualtiesUndead";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.CasualtiesUndeadClient = TCA.Compat.CasualtiesUndeadClient or {};

local C = TCA.Compat.CasualtiesUndeadClient;

C.DISSECT_KEY = "ContextMenu_CU_Dissect";

function C.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test or not context then
        return;
    end
    local name = getText(C.DISSECT_KEY);
    if context:getOptionFromName(name) then
        context:removeOptionByName(name);
    end
end

function C.register()
    if C.registered or not TCA.Compat.CasualtiesUndead.isActive() then
        return;
    end
    Events.OnFillWorldObjectContextMenu.Add(C.onFillWorldObjectContextMenu);
    C.registered = true;
end

Events.OnGameStart.Add(C.register);
