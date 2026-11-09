TCA = TCA or {};
TCA.Sound = TCA.Sound or {};

local S = TCA.Sound;

S.FADE_MS = 120;

function S.getEmitter(character)
    if not character then
        return nil;
    end
    return character:getEmitter();
end

function S.play(character, name, volume)
    local emitter = S.getEmitter(character);
    if not emitter then
        return nil;
    end
    local id = emitter:playSound(name);
    if not id or id == 0 then
        return nil;
    end
    if volume then
        emitter:setVolume(id, volume);
    end
    return id;
end

function S.isPlaying(character, id)
    local emitter = S.getEmitter(character);
    if not emitter or not id then
        return false;
    end
    return emitter:isPlaying(id);
end

function S.setVolume(character, id, volume)
    local emitter = S.getEmitter(character);
    if emitter and id then
        emitter:setVolume(id, volume);
    end
end

function S.stop(character, id)
    local emitter = S.getEmitter(character);
    if emitter and id then
        emitter:stopSound(id);
    end
end

S.fading = S.fading or {};

function S.fadeOut(character, id, volume, ms)
    if not id then
        return;
    end
    local entry = {};
    entry.character = character;
    entry.id = id;
    entry.volume = volume or 1;
    entry.start = getTimestampMs();
    entry.ms = ms or S.FADE_MS;
    table.insert(S.fading, entry);
end

function S.updateFades()
    if #S.fading == 0 then
        return;
    end
    local now = getTimestampMs();
    local keep = {};
    for _, entry in ipairs(S.fading) do
        local t = (now - entry.start) / entry.ms;
        if t >= 1 or not S.isPlaying(entry.character, entry.id) then
            S.stop(entry.character, entry.id);
        else
            S.setVolume(entry.character, entry.id, entry.volume * (1 - t));
            table.insert(keep, entry);
        end
    end
    S.fading = keep;
end

Events.OnTick.Add(S.updateFades);
Events.OnTickEvenPaused.Add(S.updateFades);
