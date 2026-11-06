--***********************************************************
--**            The Coroner: Autopsy Mod (TCA)            **
--**  Fonctions partagees client / serveur                 **
--***********************************************************

TCA = TCA or {};

-- Meubles reconnus comme "table d'operation" meme s'ils n'ont pas
-- le drapeau IsTable. Cle = GroupName + "_" + CustomName (espaces -> _),
-- comme dans Translate/EN/Moveables.json.
TCA.EXTRA_TABLES = {
    ["Morgue_Table"] = true,
    ["Large_Medical_Bed"] = true,
    ["Patient_Chair"] = true,
    ["Dentist_Patient_Chair"] = true,
    ["Long_Metal_Table"] = true,
};

-- Noms de sprites a ajouter a la main si une table n'est pas detectee
-- (ex: ["location_community_medical_01_0"] = true).
TCA.EXTRA_SPRITES = {};

-- Mots qui excluent un objet meme s'il a le drapeau IsTable.
TCA.EXCLUDED_WORDS = { "Counter" };

-- Hauteur de surface (en pixels, 96 = un etage) si la tuile n'en declare pas.
TCA.DEFAULT_SURFACE = 34;

-- Distance max (en cases) entre la table et le cadavre a poser.
TCA.MAX_BODY_DISTANCE = 2.5;

function TCA.getMoveableKey(obj)
    local props = obj:getProperties();
    if not props then
        return nil;
    end
    local custom = props:get("CustomName");
    if not custom or custom == "" then
        return nil;
    end
    local group = props:get("GroupName");
    local key = custom;
    if group and group ~= "" then
        key = group .. " " .. custom;
    end
    key = string.gsub(key, " ", "_");
    return key;
end

local function containsExcludedWord(key)
    if not key then
        return false;
    end
    for _, word in ipairs(TCA.EXCLUDED_WORDS) do
        if string.find(key, word, 1, true) then
            return true;
        end
    end
    return false;
end

function TCA.isTableObject(obj)
    if not obj then
        return false;
    end
    if instanceof(obj, "IsoWorldInventoryObject") or instanceof(obj, "IsoMovingObject") then
        return false;
    end
    local sprite = obj:getSprite();
    if not sprite or not obj:getProperties() then
        return false;
    end
    if obj:isTableTopObject() then
        return false;
    end

    local spriteName = sprite:getName();
    if spriteName and TCA.EXTRA_SPRITES[spriteName] then
        return true;
    end

    local key = TCA.getMoveableKey(obj);
    if key and TCA.EXTRA_TABLES[key] then
        return true;
    end

    if obj:isTableSurface() and not containsExcludedWord(key) then
        return true;
    end
    return false;
end

function TCA.findTableOnSquare(square)
    if not square then
        return nil;
    end
    local objects = square:getObjects();
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i);
        if TCA.isTableObject(obj) then
            return obj;
        end
    end
    return nil;
end

-- Identifiant servant a reconnaitre deux morceaux d'un meme meuble :
-- cle de meuble si elle existe, sinon nom du jeu de tuiles (sans le numero).
local function getPieceId(obj)
    local key = TCA.getMoveableKey(obj);
    if key then
        return key;
    end
    local sprite = obj:getSprite();
    local name = sprite and sprite:getName() or nil;
    if not name then
        return nil;
    end
    local tileset = string.match(name, "^(.*)_%d+$");
    return tileset or name;
end

-- Cherche, sur une case voisine, un morceau de la meme table.
local function findNeighbourPiece(tableObj)
    local sq = tableObj:getSquare();
    local id = getPieceId(tableObj);
    if not id then
        return nil, 0, 0;
    end
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } };
    for _, d in ipairs(dirs) do
        local nsq = getCell():getGridSquare(sq:getX() + d[1], sq:getY() + d[2], sq:getZ());
        if nsq then
            local objects = nsq:getObjects();
            for i = 0, objects:size() - 1 do
                local o = objects:get(i);
                if TCA.isTableObject(o) and getPieceId(o) == id then
                    return o, d[1], d[2];
                end
            end
        end
    end
    return nil, 0, 0;
end

-- Renvoie l'emprise de la table : origine (x, y), largeur, hauteur en cases.
-- 1) grille de sprites du meuble si elle existe ;
-- 2) sinon, morceau identique sur une case voisine ;
-- 3) sinon, 1 x 1.
function TCA.getTableFootprint(tableObj)
    local sq = tableObj:getSquare();
    local sx = sq:getX();
    local sy = sq:getY();

    local sprite = tableObj:getSprite();
    local grid = sprite and sprite:getSpriteGrid() or nil;
    if grid then
        local px = grid:getSpriteGridPosX(sprite);
        local py = grid:getSpriteGridPosY(sprite);
        local gw = grid:getWidth();
        local gh = grid:getHeight();
        if px >= 0 and py >= 0 and gw * gh >= 2 then
            return sx - px, sy - py, gw, gh;
        end
    end

    local piece, dx, dy = findNeighbourPiece(tableObj);
    if piece then
        if dx ~= 0 then
            return math.min(sx, sx + dx), sy, 2, 1;
        end
        return sx, math.min(sy, sy + dy), 1, 2;
    end

    return sx, sy, 1, 1;
end

-- Une table doit faire au moins 2 cases dans une direction.
function TCA.isLongTable(tableObj)
    local ox, oy, w, h = TCA.getTableFootprint(tableObj);
    return math.max(w, h) >= 2;
end

-- Affiche dans la console ce que le mod detecte (TCA.DEBUG = true).
TCA.DEBUG = false;

function TCA.debugTable(tableObj)
    if not TCA.DEBUG then
        return;
    end
    local sprite = tableObj:getSprite();
    local ox, oy, w, h = TCA.getTableFootprint(tableObj);
    print("[TCA] sprite=" .. tostring(sprite and sprite:getName()) .. " cle=" .. tostring(TCA.getMoveableKey(tableObj)) .. " grille=" .. tostring(sprite and sprite:getSpriteGrid() ~= nil) .. " emprise=" .. ox .. "," .. oy .. " " .. w .. "x" .. h);
end

function TCA.getSurfaceZ(tableObj)
    local surf = tableObj:getSurfaceOffsetNoTable();
    if not surf or surf <= 0 then
        surf = TCA.DEFAULT_SURFACE;
    end
    return tableObj:getSquare():getZ() + surf / 96;
end

-- Calcule la position, la hauteur et l'orientation du cadavre sur la table.
function TCA.computePlacement(tableObj, character)
    local sq = tableObj:getSquare();
    if not sq then
        return nil;
    end
    local ox, oy, w, h = TCA.getTableFootprint(tableObj);
    if math.max(w, h) < 2 then
        return nil;
    end
    local z = sq:getZ();
    local cx = ox + w / 2;
    local cy = oy + h / 2;

    -- Le corps est allonge selon sa direction "avant" : on l'aligne
    -- sur le grand cote de la table.
    local dirX = 1;
    local dirY = 0;
    if h > w then
        dirX = 0;
        dirY = 1;
    elseif h == w and character then
        -- Table carree (2x2...) : le corps est perpendiculaire au joueur.
        local dx = math.abs(character:getX() - cx);
        local dy = math.abs(character:getY() - cy);
        if dx > dy then
            dirX = 0;
            dirY = 1;
        end
    end

    -- Leger decalage pour que le centre ne tombe pas pile sur une limite de case.
    local bx = cx - 0.01;
    local by = cy - 0.01;
    local bodySquare = getCell():getGridSquare(math.floor(bx), math.floor(by), z);
    if not bodySquare then
        bodySquare = sq;
    end

    local placement = {};
    placement.x = bx;
    placement.y = by;
    placement.z = TCA.getSurfaceZ(tableObj);
    placement.square = bodySquare;
    placement.dirX = dirX;
    placement.dirY = dirY;
    return placement;
end

local function isBodyOnFloor(body)
    local bsq = body:getSquare();
    if not bsq then
        return false;
    end
    return body:getZ() - bsq:getZ() < 0.05;
end

function TCA.getSquaresAround(tableObj, radius)
    local squares = {};
    local sq = tableObj:getSquare();
    local z = sq:getZ();
    local ox, oy, w, h = TCA.getTableFootprint(tableObj);
    for x = ox - radius, ox + w - 1 + radius do
        for y = oy - radius, oy + h - 1 + radius do
            local s = getCell():getGridSquare(x, y, z);
            if s then
                table.insert(squares, s);
            end
        end
    end
    return squares;
end

-- Y a-t-il deja un cadavre pose sur cette table ?
function TCA.tableHasBody(tableObj)
    local squares = TCA.getSquaresAround(tableObj, 0);
    for _, s in ipairs(squares) do
        local list = s:getStaticMovingObjects();
        for i = 0, list:size() - 1 do
            local o = list:get(i);
            if instanceof(o, "IsoDeadBody") and not isBodyOnFloor(o) then
                return true;
            end
        end
    end
    return false;
end

-- Cherche un cadavre au sol pres de la table.
-- Priorite au dernier cadavre lache par ce joueur.
function TCA.findBodyNearTable(tableObj, character)
    local playerID = nil;
    if character then
        if isMultiplayer() then
            playerID = character:getOnlineID();
        else
            playerID = character:getPlayerNum();
        end
    end

    local ox, oy, w, h = TCA.getTableFootprint(tableObj);
    local cx = ox + w / 2;
    local cy = oy + h / 2;
    local best = nil;
    local bestDist = 9999;
    local mine = nil;

    local squares = TCA.getSquaresAround(tableObj, 2);
    for _, s in ipairs(squares) do
        local list = s:getStaticMovingObjects();
        for i = 0, list:size() - 1 do
            local o = list:get(i);
            if instanceof(o, "IsoDeadBody") and not o:isAnimal() and isBodyOnFloor(o) then
                local dx = o:getX() - cx;
                local dy = o:getY() - cy;
                local dist = math.sqrt(dx * dx + dy * dy);
                if dist <= TCA.MAX_BODY_DISTANCE + math.max(w, h) / 2 then
                    if playerID ~= nil and o:getModData()["lastPlayerGrabbed"] == playerID then
                        mine = o;
                    end
                    if dist < bestDist then
                        best = o;
                        bestDist = dist;
                    end
                end
            end
        end
    end

    return mine or best;
end

-- Cherche le cadavre pose sur cette table (s'il y en a un).
function TCA.findBodyOnTable(tableObj)
    local squares = TCA.getSquaresAround(tableObj, 0);
    for _, s in ipairs(squares) do
        local list = s:getStaticMovingObjects();
        for i = 0, list:size() - 1 do
            local o = list:get(i);
            if instanceof(o, "IsoDeadBody") and not isBodyOnFloor(o) then
                return o;
            end
        end
    end
    return nil;
end

-- Recree le cadavre a une nouvelle position (meme technique que le jeu
-- quand il sort un cadavre d'un conteneur). A appeler la ou complete()
-- s'execute (serveur en multijoueur, local en solo).
function TCA.relocateBody(body, square, x, y, z, dirX, dirY, onTable)
    if not body or not square then
        return false;
    end
    local item = body:getItem();
    if not item then
        return false;
    end
    local newBody = item:loadCorpseFromByteData(nil);
    if not newBody then
        return false;
    end

    -- L'objet cadavre peut avoir ete cree avant les dernieres modifications :
    -- on recopie les donnees a jour (progression d'autopsie, etc.).
    local newData = newBody:getModData();
    for k, v in pairs(body:getModData()) do
        newData[k] = v;
    end

    local oldSquare = body:getSquare();
    if oldSquare then
        oldSquare:removeCorpse(body, false);
    end

    newBody:setX(x);
    newBody:setY(y);
    newBody:setZ(z);
    newBody:setSquare(square);
    newBody:setCurrent(square);
    if dirX and dirY then
        newBody:setForwardDirection(dirX, dirY);
    end
    newBody:getModData()["lastPlayerGrabbed"] = nil;
    if onTable then
        newBody:getModData()["TCA_OnTable"] = true;
    else
        newBody:getModData()["TCA_OnTable"] = nil;
    end

    square:addCorpse(newBody, false);
    newBody:invalidateCorpse();
    newBody:setInvalidateNextRender(true);

    if isServer() then
        sendCorpse(newBody);
    end
    return true;
end

-- Pose le cadavre sur la table.
function TCA.placeBodyOnTable(body, tableObj, character)
    if not body or not tableObj then
        return false;
    end
    local p = TCA.computePlacement(tableObj, character);
    if not p then
        return false;
    end
    return TCA.relocateBody(body, p.square, p.x, p.y, p.z, p.dirX, p.dirY, true);
end

-- Redescend le cadavre de la table, au sol aux pieds du joueur.
function TCA.removeBodyFromTable(body, character)
    if not body or not character then
        return false;
    end
    local sq = character:getCurrentSquare();
    if not sq then
        return false;
    end
    local x = character:getX();
    local y = character:getY();
    local z = sq:getApparentZ(x - sq:getX(), y - sq:getY());
    local dir = body:getAnimForwardDirection(Vector2.new());
    return TCA.relocateBody(body, sq, x, y, z, dir:getX(), dir:getY(), false);
end
