TCA = TCA or {};
TCA.Knowledge = TCA.Knowledge or {};

local K = TCA.Knowledge;

K.TIERS = {
    { id = "TCA_Forensics1", book = "TCA.ForensicsBook1", level = 5, lines = { 1, 3, 6, 9 } },
    { id = "TCA_Forensics2", book = "TCA.ForensicsBook2", level = 7, lines = { 4, 5, 7 } },
    { id = "TCA_Forensics3", book = "TCA.ForensicsBook3", level = 9, lines = { 2, 8 } },
};

function K.hasReadTier(character, tier)
    return character ~= nil and character:isRecipeActuallyKnown(tier.id);
end

function K.hasTier(character, tier)
    if not character then
        return false;
    end
    if K.hasReadTier(character, tier) then
        return true;
    end
    return character:getPerkLevel(Perks.Doctor) >= tier.level;
end

function K.countTiers(character)
    local count = 0;
    for i = 1, #K.TIERS do
        if K.hasTier(character, K.TIERS[i]) then
            count = count + 1;
        end
    end
    return count;
end
