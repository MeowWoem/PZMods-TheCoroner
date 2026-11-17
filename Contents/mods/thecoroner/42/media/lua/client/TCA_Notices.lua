require "ISUI/ISModalRichText";

TCA = TCA or {};
TCA.Notices = TCA.Notices or {};

local N = TCA.Notices;

N.FILE = "TheCoroner_notices.txt";
N.WIDTH = 640;
N.HEIGHT = 200;

function N.isModActivated(id)
    local mods = getActivatedMods();
    if not mods then
        return false;
    end
    return mods:contains(id) or mods:contains("\\" .. id);
end

function N.isZVVActive()
    return N.isModActivated("ZVirusVaccine42BETA");
end

N.LIST = {
    { id = "zvv_compat_1", check = N.isZVVActive, key = "IGUI_TCA_NoticeZVV1" },
};

function N.readShown()
    local shown = {};
    local reader = getFileReader(N.FILE, true);
    if not reader then
        return shown;
    end
    local line = reader:readLine();
    while line ~= nil do
        shown[line] = true;
        line = reader:readLine();
    end
    reader:close();
    return shown;
end

function N.writeShown(shown)
    local writer = getFileWriter(N.FILE, true, false);
    if not writer then
        return;
    end
    for id, value in pairs(shown) do
        if value then
            writer:write(id .. "\n");
        end
    end
    writer:close();
end

function N.getText(notice)
    return " <CENTRE> <H1> " .. getText("IGUI_TCA_NoticeTitle") .. " <LINE> <LINE> <LEFT> <TEXT> " .. getText(notice.key);
end

function N.onClose(target, button)
end

function N.show(notice)
    local w = N.WIDTH;
    local x = (getCore():getScreenWidth() - w) / 2;
    local y = (getCore():getScreenHeight() - N.HEIGHT) / 2;
    local modal = ISModalRichText:new(x, y, w, N.HEIGHT, N.getText(notice), false, nil, N.onClose);
    modal:initialise();
    modal:addToUIManager();
    modal:setAlwaysOnTop(true);
    modal:setHeightToContents();
    modal:setY(math.max(20, (getCore():getScreenHeight() - modal:getHeight()) / 2));
    return modal;
end

function N.check()
    local shown = N.readShown();
    local changed = false;
    for _, notice in ipairs(N.LIST) do
        if not shown[notice.id] and notice.check() then
            N.show(notice);
            shown[notice.id] = true;
            changed = true;
        end
    end
    if changed then
        N.writeShown(shown);
    end
end

Events.OnMainMenuEnter.Add(N.check);
Events.OnGameStart.Add(N.check);
