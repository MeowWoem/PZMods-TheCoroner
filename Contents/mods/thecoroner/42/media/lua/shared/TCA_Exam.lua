require "TCA_Shared";
require "TCA_DeathTime";
require "TCA_Cold";
require "TCA_Autopsy";

TCA = TCA or {};
TCA.Exam = TCA.Exam or {};

local E = TCA.Exam;
local D = TCA.DeathTime;
local C = TCA.Cold;

E.THERMOMETER_TYPES = { "TCA.Thermometer" };

E.BODY_TEMP = 37.0;
E.FRIDGE_TEMP = 3.0;
E.COOLING_RATE = 0.065;
E.TEMP_PLATEAU = 1.0;

E.RIGOR_FACTOR = 0.2;
E.LIVOR_FACTOR = 1.0;
E.JAW_LEAD = 3;
E.RIGOR_ONSET = 2;
E.RIGOR_FULL = 12;
E.RIGOR_HOLD = 24;
E.RIGOR_GONE = 48;
E.RIGOR_ONSET_LEVEL = 0.15;

E.LIVOR_APPEAR = 0.5;
E.LIVOR_VISIBLE = 4;
E.LIVOR_FIX_START = 6;
E.LIVOR_FIXED = 12;

E.DECOMP_HOURS = { 24, 72, 168, 480, 1440 };
E.EYES_HOURS = { 2, 12, 24 };
E.EYES_FACTOR = 0.3;
E.INSECT_HOURS = { 2, 20, 44, 72, 144, 288 };
E.INSECT_MIN_TEMP = 10;
E.INSECT_REF_TEMP = 25;
E.INSECT_MAX_RATE = 1.5;
E.MAGGOT_ITEM = "Base.Maggots";
E.MAGGOT_COUNT = { [2] = 3, [3] = 5, [4] = 8 };
E.KEY_MAGGOTS = "TCA_MaggotsTaken";

E.MIN_HOURS = 0.5;
E.MAX_HOURS = 17520;

E.XP_MAX = 8;
E.WIDE_RATIO = 30;
E.XP_MIN_FACTOR = 0.15;

E.KEY_RESULT = "TCA_Exam";
E.KEY_OBS = "TCA_ExamObs";
E.OBS_ZONES = { temp = true, eyes = true, jaw = true, arm = true, livor = true, decomp = true, insects = true, w_Hand_L = true, w_Hand_R = true, w_ForeArm_L = true, w_ForeArm_R = true, w_UpperArm_L = true, w_UpperArm_R = true, w_Torso_Upper = true, w_Torso_Lower = true, w_Head = true, w_Neck = true, w_Groin = true, w_UpperLeg_L = true, w_UpperLeg_R = true, w_LowerLeg_L = true, w_LowerLeg_R = true, w_Foot_L = true, w_Foot_R = true };
E.OBS_MAX_LEN = 120;
E.OBS_AGE_SHOW = 0.25;

E.TICKS = { 1, 6, 24, 48, 168, 720, 2160, 8760 };

local function clamp(v, lo, hi)
    if v < lo then
        return lo;
    end
    if v > hi then
        return hi;
    end
    return v;
end

local function ramp(h, a, b)
    if b <= a then
        return 1;
    end
    return clamp((h - a) / (b - a), 0, 1);
end

function E.findThermometer(character)
    local inv = character:getInventory();
    for _, itemType in ipairs(E.THERMOMETER_TYPES) do
        local item = inv:getFirstTypeRecurse(itemType);
        if item then
            return item;
        end
    end
    return nil;
end

function E.getLevel(character)
    return character:getPerkLevel(Perks.Doctor);
end

function E.noise(body, key, level)
    local seed = key .. ":" .. tostring(level) .. ":" .. tostring(math.floor(D.get(body) * 1000));
    local h = 5381;
    for i = 1, string.len(seed) do
        h = (h * 33 + string.byte(seed, i)) % 2147483647;
    end
    for i = 1, 3 do
        h = (h * 48271 + 1) % 2147483647;
    end
    return (h % 20001) / 10000 - 1;
end

function E.getAmbient(body)
    local climate = getClimateManager();
    local sq = body:getSquare();
    if sq then
        return climate:getAirTemperatureForSquare(sq);
    end
    return climate:getTemperature();
end

function E.coolFrom(startTemp, envTemp, hours)
    return envTemp + (startTemp - envTemp) * math.exp(-E.COOLING_RATE * math.max(0, hours));
end

function E.getBodyTemp(body, ambient)
    local age = D.getHoursSinceDeath(body);
    local left = C.getHoursSinceLeft(body);
    local cold = math.min(C.getColdHours(body), age);
    if left == nil or cold <= 0 then
        return E.coolFrom(E.BODY_TEMP, ambient, age - E.TEMP_PLATEAU);
    end
    local ageAtLeft = math.max(0, age - left);
    local entryAge = math.max(0, ageAtLeft - cold);
    local entryTemp = E.coolFrom(E.BODY_TEMP, ambient, entryAge - E.TEMP_PLATEAU);
    local exitTemp = E.coolFrom(entryTemp, E.FRIDGE_TEMP, cold);
    return E.coolFrom(exitTemp, ambient, left);
end

function E.rigorAt(h)
    if h <= 0 then
        return 0;
    end
    if h < E.RIGOR_ONSET then
        return E.RIGOR_ONSET_LEVEL * h / E.RIGOR_ONSET;
    end
    if h < E.RIGOR_FULL then
        return E.RIGOR_ONSET_LEVEL + (1 - E.RIGOR_ONSET_LEVEL) * ramp(h, E.RIGOR_ONSET, E.RIGOR_FULL);
    end
    if h < E.RIGOR_HOLD then
        return 1;
    end
    return 1 - ramp(h, E.RIGOR_HOLD, E.RIGOR_GONE);
end

function E.getRigor(body, joint)
    local h = C.getEffectiveHours(body, E.RIGOR_FACTOR);
    if joint == "jaw" then
        h = h + E.JAW_LEAD;
    end
    return E.rigorAt(h);
end

function E.getLivor(body)
    local h = C.getEffectiveHours(body, E.LIVOR_FACTOR);
    return ramp(h, E.LIVOR_APPEAR, E.LIVOR_VISIBLE), ramp(h, E.LIVOR_FIX_START, E.LIVOR_FIXED);
end

function E.getDecompStage(body)
    if body:isSkeleton() then
        return #E.DECOMP_HOURS;
    end
    local h = C.getEffectiveHours(body, C.DECAY_FACTOR);
    local stage = 0;
    for _, limit in ipairs(E.DECOMP_HOURS) do
        if h >= limit then
            stage = stage + 1;
        end
    end
    return stage;
end

function E.countStage(hours, limits)
    local stage = 0;
    for _, limit in ipairs(limits) do
        if hours >= limit then
            stage = stage + 1;
        end
    end
    return stage;
end

function E.getEyesStage(body)
    return E.countStage(C.getEffectiveHours(body, E.EYES_FACTOR), E.EYES_HOURS);
end

function E.getInsectRate(body)
    local t = E.getAmbient(body);
    return clamp((t - E.INSECT_MIN_TEMP) / (E.INSECT_REF_TEMP - E.INSECT_MIN_TEMP), 0, E.INSECT_MAX_RATE);
end

function E.getInsectStage(body)
    if body:isSkeleton() then
        return #E.INSECT_HOURS;
    end
    local hours = C.getEffectiveHours(body, 0) * E.getInsectRate(body);
    return E.countStage(hours, E.INSECT_HOURS);
end

function E.getHarvestCount(body)
    if body:getModData()[E.KEY_MAGGOTS] then
        return 0;
    end
    return E.MAGGOT_COUNT[E.getInsectStage(body)] or 0;
end

function E.misreadStage(body, key, stage, maxStage, level)
    if math.abs(E.noise(body, key .. "_b", level)) < E.getMisreadChance(level) then
        if E.noise(body, key .. "_a", level) >= 0 then
            stage = stage + 1;
        else
            stage = stage - 1;
        end
    end
    return math.floor(clamp(stage, 0, maxStage));
end

function E.readEyes(body, level)
    return E.misreadStage(body, "eyes", E.getEyesStage(body), #E.EYES_HOURS, level);
end

function E.readInsects(body, level)
    return E.misreadStage(body, "insects", E.getInsectStage(body), #E.INSECT_HOURS, level);
end

function E.getEyesText(stage)
    return getText("IGUI_TCA_ExamEyes" .. tostring(stage));
end

function E.getInsectsText(stage)
    return getText("IGUI_TCA_ExamInsects" .. tostring(stage));
end

function E.getTempSigma(level)
    return math.max(0.3, 2.5 - 0.22 * level);
end

function E.getFeelSigma(level)
    return math.max(0.05, 0.3 - 0.025 * level);
end

function E.getMisreadChance(level)
    return math.max(0.05, 0.45 - 0.04 * level);
end

function E.readTemperature(body, level)
    local ambient = E.getAmbient(body);
    local sigma = E.getTempSigma(level);
    local bodyTemp = E.getBodyTemp(body, ambient) + E.noise(body, "temp", level) * sigma;
    local airTemp = ambient + E.noise(body, "air", level) * sigma * 0.5;
    local reading = {};
    reading.body = bodyTemp;
    reading.air = airTemp;
    reading.decimals = 0;
    if level >= 3 then
        reading.decimals = 1;
    end
    return reading;
end

function E.readRigor(body, joint, level)
    local value = E.getRigor(body, joint) + E.noise(body, "rigor_" .. joint, level) * E.getFeelSigma(level);
    return clamp(value, 0, 1);
end

function E.readLivor(body, level)
    local visible, fixed = E.getLivor(body);
    local sigma = E.getFeelSigma(level);
    local reading = {};
    reading.visible = clamp(visible + E.noise(body, "livor_v", level) * sigma, 0, 1);
    reading.blanch = clamp(1 - fixed + E.noise(body, "livor_f", level) * sigma, 0, 1);
    return reading;
end

function E.readDecomp(body, level)
    local stage = E.getDecompStage(body);
    if math.abs(E.noise(body, "decomp_b", level)) < E.getMisreadChance(level) then
        if E.noise(body, "decomp_a", level) >= 0 then
            stage = stage + 1;
        else
            stage = stage - 1;
        end
    end
    return math.floor(clamp(stage, 0, #E.DECOMP_HOURS));
end

function E.readAll(body, level)
    local values = {};
    values.temp = E.readTemperature(body, level);
    values.jaw = E.readRigor(body, "jaw", level);
    values.arm = E.readRigor(body, "arm", level);
    values.livor = E.readLivor(body, level);
    values.decomp = E.readDecomp(body, level);
    values.eyes = E.readEyes(body, level);
    values.insects = E.readInsects(body, level);
    return values;
end

function E.getRigorKey(value, level)
    if level < 4 then
        if value < 0.33 then
            return "IGUI_TCA_ExamRigorCoarse0";
        elseif value < 0.75 then
            return "IGUI_TCA_ExamRigorCoarse1";
        end
        return "IGUI_TCA_ExamRigorCoarse2";
    end
    if value < 0.1 then
        return "IGUI_TCA_ExamRigor0";
    elseif value < 0.35 then
        return "IGUI_TCA_ExamRigor1";
    elseif value < 0.65 then
        return "IGUI_TCA_ExamRigor2";
    elseif value < 0.9 then
        return "IGUI_TCA_ExamRigor3";
    end
    return "IGUI_TCA_ExamRigor4";
end

function E.getLivorText(reading, level)
    if reading.visible < 0.15 then
        return getText("IGUI_TCA_ExamLivorNone");
    end
    local key = "IGUI_TCA_ExamLivorFixed";
    if reading.blanch > 0.66 then
        key = "IGUI_TCA_ExamLivorBlanch";
    elseif reading.blanch > 0.25 then
        key = "IGUI_TCA_ExamLivorPartial";
    end
    local text = getText(key);
    if level >= 5 then
        local intensity = "IGUI_TCA_ExamLivorStrong";
        if reading.visible < 0.6 then
            intensity = "IGUI_TCA_ExamLivorFaint";
        end
        text = getText(intensity) .. " " .. text;
    end
    return text;
end

function E.getDecompText(stage)
    return getText("IGUI_TCA_ExamDecomp" .. tostring(stage));
end

function E.formatTemp(celsius, decimals)
    local value = celsius;
    local key = "IGUI_TCA_ExamCelsius";
    if not getCore():getOptionDisplayAsCelsius() then
        value = celsius * 9 / 5 + 32;
        key = "IGUI_TCA_ExamFahrenheit";
    end
    local text = string.format("%." .. tostring(decimals) .. "f", value);
    return getText(key, text);
end

function E.getTempText(reading)
    return getText("IGUI_TCA_ExamTempValue", E.formatTemp(reading.body, reading.decimals), E.formatTemp(reading.air, reading.decimals));
end

function E.hoursToPos(hours)
    local h = clamp(hours, E.MIN_HOURS, E.MAX_HOURS);
    return math.log(h / E.MIN_HOURS) / math.log(E.MAX_HOURS / E.MIN_HOURS);
end

function E.posToHours(pos)
    return E.MIN_HOURS * math.exp(clamp(pos, 0, 1) * math.log(E.MAX_HOURS / E.MIN_HOURS));
end

function E.formatHours(hours)
    if hours < 1 then
        return getText("IGUI_TCA_ExamLessHour");
    end
    if hours < 48 then
        return getText("IGUI_TCA_ExamHours", tostring(math.floor(hours + 0.5)));
    end
    local days = hours / 24;
    if days < 60 then
        return getText("IGUI_TCA_ExamDays", tostring(math.floor(days + 0.5)));
    end
    if days < 365 then
        return getText("IGUI_TCA_ExamMonths", tostring(math.floor(days / 30 + 0.5)));
    end
    return getText("IGUI_TCA_ExamYears", string.format("%.1f", days / 365));
end

function E.sanitizeRange(minHours, maxHours)
    local lo = clamp(tonumber(minHours) or E.MIN_HOURS, E.MIN_HOURS, E.MAX_HOURS);
    local hi = clamp(tonumber(maxHours) or E.MAX_HOURS, E.MIN_HOURS, E.MAX_HOURS);
    if hi < lo then
        local tmp = lo;
        lo = hi;
        hi = tmp;
    end
    return lo, hi;
end

function E.score(body, minHours, maxHours)
    local lo, hi = E.sanitizeRange(minHours, maxHours);
    local truth = D.getHoursSinceDeath(body);
    local ok = truth >= lo and truth <= hi;
    if truth < E.MIN_HOURS and lo <= E.MIN_HOURS then
        ok = true;
    end
    if not ok then
        return false, 0, lo, hi;
    end
    local ratio = hi / math.max(lo, E.MIN_HOURS);
    local factor = clamp(1 - math.log(ratio) / math.log(E.WIDE_RATIO), E.XP_MIN_FACTOR, 1);
    return true, E.XP_MAX * factor, lo, hi;
end

function E.getResult(body)
    local stored = body:getModData()[E.KEY_RESULT];
    if type(stored) ~= "string" then
        return nil;
    end
    local lo, hi, ok = string.match(stored, "^([%d%.]+),([%d%.]+),(%d)$");
    if not lo then
        return nil;
    end
    local result = {};
    result.minHours = tonumber(lo);
    result.maxHours = tonumber(hi);
    result.ok = ok == "1";
    return result;
end

function E.storeResult(body, minHours, maxHours, ok)
    local flag = 0;
    if ok then
        flag = 1;
    end
    body:getModData()[E.KEY_RESULT] = string.format("%.3f,%.3f,%d", minHours, maxHours, flag);
end

function E.resetResult(body)
    body:getModData()[E.KEY_RESULT] = nil;
    body:getModData()[E.KEY_OBS] = nil;
    body:getModData()["TCA_CauseResult"] = nil;
end

function E.getObserverKey(character)
    local name = character:getUsername();
    if not name or name == "" then
        name = character:getFullName();
    end
    return tostring(name);
end

function E.encodeObservation(zone, reading, level, time)
    if zone == "temp" then
        return string.format("%.3f|%d|%.3f|%.3f|%d", time, level, reading.body, reading.air, reading.decimals);
    elseif zone == "jaw" or zone == "arm" then
        return string.format("%.3f|%d|%.4f", time, level, reading);
    elseif zone == "livor" then
        return string.format("%.3f|%d|%.4f|%.4f", time, level, reading.visible, reading.blanch);
    elseif zone == "decomp" or zone == "eyes" or zone == "insects" then
        return string.format("%.3f|%d|%d", time, level, reading);
    elseif TCA.Wounds and TCA.Wounds.isRegion(zone) then
        return string.format("%.3f|%d|0", time, level);
    end
    return nil;
end

function E.splitObservation(str)
    local parts = {};
    for part in string.gmatch(str, "[^|]+") do
        table.insert(parts, tonumber(part));
    end
    return parts;
end

function E.decodeObservation(zone, str)
    if type(str) ~= "string" then
        return nil;
    end
    local p = E.splitObservation(str);
    if not p[1] or not p[2] or not p[3] then
        return nil;
    end
    local obs = {};
    obs.time = p[1];
    obs.level = p[2];
    if zone == "temp" then
        if not p[4] or not p[5] then
            return nil;
        end
        obs.reading = { body = p[3], air = p[4], decimals = p[5] };
    elseif zone == "livor" then
        if not p[4] then
            return nil;
        end
        obs.reading = { visible = p[3], blanch = p[4] };
    else
        obs.reading = p[3];
    end
    return obs;
end

function E.getObservationText(zone, obs, body)
    if TCA.Wounds and TCA.Wounds.isRegion(zone) then
        if not body then
            return nil;
        end
        return TCA.Wounds.getRegionText(body, zone, obs.level);
    end
    if zone == "temp" then
        return E.getTempText(obs.reading);
    elseif zone == "jaw" or zone == "arm" then
        return getText(E.getRigorKey(obs.reading, obs.level));
    elseif zone == "livor" then
        return E.getLivorText(obs.reading, obs.level);
    elseif zone == "decomp" then
        return E.getDecompText(obs.reading);
    elseif zone == "eyes" then
        return E.getEyesText(obs.reading);
    elseif zone == "insects" then
        return E.getInsectsText(obs.reading);
    end
    return nil;
end

function E.getObservations(body, key)
    local all = body:getModData()[E.KEY_OBS];
    if type(all) ~= "table" then
        return nil;
    end
    local mine = all[key];
    if type(mine) ~= "table" then
        return nil;
    end
    return mine;
end

function E.isValidObservation(zone, data)
    return E.OBS_ZONES[zone] == true and type(data) == "string" and #data <= E.OBS_MAX_LEN and E.decodeObservation(zone, data) ~= nil;
end

function E.storeObservation(body, key, zone, data)
    if not E.isValidObservation(zone, data) then
        return false;
    end
    local md = body:getModData();
    if type(md[E.KEY_OBS]) ~= "table" then
        md[E.KEY_OBS] = {};
    end
    if type(md[E.KEY_OBS][key]) ~= "table" then
        md[E.KEY_OBS][key] = {};
    end
    md[E.KEY_OBS][key][zone] = data;
    return true;
end

function E.showResult(character, ok, xp)
    if not character then
        return;
    end
    if ok then
        HaloTextHelper.addGoodText(character, getText("IGUI_TCA_ExamRight"));
        if xp and xp > 0 then
            TCA.Autopsy.showXpHalo(character, xp);
        end
        return;
    end
    HaloTextHelper.addBadText(character, getText("IGUI_TCA_ExamWrong"));
end

function E.notifyResult(character, ok, xp)
    if isServer() then
        local args = {};
        args.ok = ok;
        args.xp = xp;
        sendServerCommand(character, "TCA", "examResult", args);
        return;
    end
    E.showResult(character, ok, xp);
end
