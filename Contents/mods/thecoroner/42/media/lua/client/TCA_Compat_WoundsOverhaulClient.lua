require "TCA_Compat_WoundsOverhaul";

TCA = TCA or {};
TCA.Compat = TCA.Compat or {};
TCA.Compat.WoundsOverhaulClient = TCA.Compat.WoundsOverhaulClient or {};

local C = TCA.Compat.WoundsOverhaulClient;

function C.getExtractionTarget()
    if not WoundsExtractGame or not WoundsExtractGame.instance then
        return nil, nil;
    end
    local game = WoundsExtractGame.instance;
    if not game.corpse or not game.bodyPart then
        return nil, nil;
    end
    local partType = game.bodyPart:getType();
    if not partType then
        return nil, nil;
    end
    return game.corpse, BodyPartType.ToString(partType);
end

function C.noteExtraction(character)
    local corpse, part = C.getExtractionTarget();
    if not corpse or not part or not TCA.Wounds.BULLET_ORGANS[part] then
        return;
    end
    local X = TCA.Compat.WoundsOverhaul;
    if isClient() then
        local args = {};
        args.x = corpse:getX();
        args.y = corpse:getY();
        args.z = corpse:getZ();
        args.part = part;
        sendClientCommand(character, X.COMMAND_MODULE, "extracted", args);
    else
        X.applyExtraction(corpse, part);
    end
end

function C.onPracticeActionNew(self, character, item, quality, placed, segs, kind)
    local action = WoundsPracticeAction.TCA_OriginalNew(self, character, item, quality, placed, segs, kind);
    if kind == "extract" and character then
        C.noteExtraction(character);
    end
    return action;
end

function C.patch()
    if not TCA.Compat.WoundsOverhaul.isActive() then
        return;
    end
    if not WoundsPracticeAction or type(WoundsPracticeAction.new) ~= "function" then
        return;
    end
    if type(WoundsPracticeAction.TCA_OriginalNew) ~= "function" then
        WoundsPracticeAction.TCA_OriginalNew = WoundsPracticeAction.new;
    end
    WoundsPracticeAction.new = C.onPracticeActionNew;
end

Events.OnGameStart.Add(C.patch);
