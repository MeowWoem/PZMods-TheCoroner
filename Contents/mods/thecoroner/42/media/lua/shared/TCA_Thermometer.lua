require "TCA_Exam";

TCA = TCA or {};
TCA.Thermometer = TCA.Thermometer or {};

local Th = TCA.Thermometer;

Th.STATUS_LIMITS = { 35.0, 36.0, 37.5, 38.0, 39.5 };

function Th.findThermometer(character)
    return TCA.Exam.findThermometer(character);
end

function Th.getDuration(character)
    if character:isTimedActionInstant() then
        return 1;
    end
    return 300 - character:getPerkLevel(Perks.Doctor) * 10;
end

function Th.readCelsius(target, level)
    local real = target:getStats():get(CharacterStat.TEMPERATURE);
    local sigma = math.max(0.05, 0.3 - 0.025 * level);
    local value = real + ZombRandFloat(-1, 1) * sigma;
    return math.floor(value * 10 + 0.5) / 10;
end

function Th.getStatusText(celsius)
    local index = #Th.STATUS_LIMITS;
    for i = 1, #Th.STATUS_LIMITS do
        if celsius < Th.STATUS_LIMITS[i] then
            index = i - 1;
            break;
        end
    end
    return getText("IGUI_TCA_TempStatus" .. tostring(index));
end

function Th.formatValue(celsius)
    return TCA.Exam.formatTemp(celsius, 1);
end

function Th.showResult(character, celsius, targetName, byName)
    if not character then
        return;
    end
    local value = Th.formatValue(celsius);
    local status = Th.getStatusText(celsius);
    local text;
    if byName then
        text = getText("IGUI_TCA_TempBy", byName, value, status);
    elseif targetName then
        text = getText("IGUI_TCA_TempOther", targetName, value, status);
    else
        text = getText("IGUI_TCA_TempSelf", value, status);
    end
    HaloTextHelper.addText(character, text);
end

function Th.getName(character)
    if isClient() or isServer() then
        return character:getDisguisedDisplayName();
    end
    return character:getDescriptor():getForename() .. " " .. character:getDescriptor():getSurname();
end

function Th.measure(character, target)
    local celsius = Th.readCelsius(target, character:getPerkLevel(Perks.Doctor));
    local isSelf = target == character;
    if not isServer() then
        if isSelf then
            Th.showResult(character, celsius, nil, nil);
        else
            Th.showResult(character, celsius, Th.getName(target), nil);
        end
        return;
    end
    local args = {};
    args.c = celsius;
    if not isSelf then
        args.target = Th.getName(target);
        local notice = {};
        notice.c = celsius;
        notice.by = Th.getName(character);
        sendServerCommand(target, "TCA", "tempResult", notice);
    end
    sendServerCommand(character, "TCA", "tempResult", args);
end

function Th.onClientCommand(module, command, player, args)
    if module ~= "TCA" or not player or not args then
        return;
    end
    if command == "tempRequest" then
        local target = getPlayerByOnlineID(args.target);
        if target and target ~= player and not target:isDead() then
            local out = {};
            out.requester = player:getOnlineID();
            sendServerCommand(target, "TCA", "tempRequest", out);
        end
    elseif command == "tempAnswer" then
        local requester = getPlayerByOnlineID(args.requester);
        if requester then
            local out = {};
            out.target = player:getOnlineID();
            out.ok = args.ok == true;
            sendServerCommand(requester, "TCA", "tempAnswer", out);
        end
    end
end

Events.OnClientCommand.Add(Th.onClientCommand);
