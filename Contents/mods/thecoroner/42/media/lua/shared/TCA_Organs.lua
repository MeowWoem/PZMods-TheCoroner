require "TCA_Shared";

TCA.Organs = TCA.Organs or {};

TCA.Organs.LIST = {
    { id = "heart", step = 2, texture = "media/textures/organs/organ_heart.png", x = -8, y = 119, w = 23, h = 28 },
    { id = "lung_l", step = 3, texture = "media/textures/organs/organ_lung_l.png", x = 5, y = 103, w = 26.5, h = 55 },
    { id = "lung_r", step = 4, texture = "media/textures/organs/organ_lung_r.png", x = -31, y = 103, w = 26.5, h = 55 },
    { id = "liver", step = 5, texture = "media/textures/organs/organ_liver.png", x = -28, y = 146.5, w = 45.5, h = 32.5 },
    { id = "stomach", step = 6, texture = "media/textures/organs/organ_stomach.png", x = -10.5, y = 147, w = 35, h = 33.5 },
    { id = "intestines", step = 7, texture = "media/textures/organs/organ_intestines.png", x = -26, y = 171.5, w = 53.5, h = 50.5 },
    { id = "pancreas", step = 8, texture = "media/textures/organs/organ_pancreas.png", x = -5.5, y = 164.5, w = 27.5, h = 16 },
    { id = "kidney_r", step = 9, texture = "media/textures/organs/organ_kidney_r.png", x = -22, y = 153.5, w = 14.5, h = 25 },
    { id = "kidney_l", step = 10, texture = "media/textures/organs/organ_kidney_l.png", x = 8, y = 153, w = 14.5, h = 25 },
    { id = "spleen", step = 11, texture = "media/textures/organs/organ_spleen.png", x = 21, y = 156, w = 8.5, h = 15 },
    { id = "bladder", step = 12, texture = "media/textures/organs/organ_bladder.png", x = -6.5, y = 203, w = 15, h = 19 },
};

function TCA.Organs.getById(id)
    for _, organ in ipairs(TCA.Organs.LIST) do
        if organ.id == id then
            return organ;
        end
    end
    return nil;
end

function TCA.Organs.getByStep(step)
    for _, organ in ipairs(TCA.Organs.LIST) do
        if organ.step == step then
            return organ;
        end
    end
    return nil;
end
