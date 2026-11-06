--***********************************************************
--**  Rendu du corps (vue de dessus) pour les mini-jeux    **
--**                                                       **
--**  Tout est en "coordonnees corps" : 1 unite = 1 pixel  **
--**  de l'image de reference (echelle 1:1).               **
--**  Origine (0, 0) : axe du corps, haut du crane.        **
--**                                                       **
--**  CANVAS : rectangle couvert par l'image de reference. **
--**  Une texture dessinee sur ce canevas (meme taille,    **
--**  meme origine) remplace automatiquement les formes.   **
--***********************************************************

TCA_BodyRenderer = TCA_BodyRenderer or {};
local R = TCA_BodyRenderer;

-- Canevas de l'image de reference : 260 x 510 px.
-- L'origine du corps (0, 0) est au pixel (130, 20) de l'image.
R.CANVAS = { x1 = -130, y1 = -20, x2 = 130, y2 = 490 };

-- Texture qui remplacera les formes geometriques quand elle existera.
-- A placer dans 42/media/textures/ (PNG 260 x 510, transparence autorisee).
R.TEXTURE_PATH = "media/textures/TCA_Body.png";

-- Calage du modele 3D sur le canevas (releve dans le panneau de reference).
R.MODEL_ZOOM = 0;
R.MODEL_X = 0;
R.MODEL_Y = -0.46;

-- Pose d'autopsie (animation fournie par le mod).
-- Etat ajoute au jeu vanilla : media/AnimSets/player-avatar/tca_autopsypose/TCA_AutopsyPose.xml
-- Animation : media/anims_X/Bob/TCA_AutopsyPose.X
-- (un mod ne peut pas fournir de groupe d'actions : un jeu d'animations a lui plante.)
R.POSE_ANIMSET = "player-avatar";
R.POSE_STATE = "tca_autopsypose";
R.DEFAULT_ANIMSET = "player-avatar";
R.DEFAULT_STATE = "idle";

-- Couleurs des formes
R.SKIN = { r = 0.55, g = 0.60, b = 0.50 };
R.SKIN_DARK = { r = 0.42, g = 0.47, b = 0.38 };
R.STEEL = { r = 0.42, g = 0.45, b = 0.48 };

-- Formes du corps. q = quad (4 points), c = cercle (centre, rayon).
-- "a" = alpha optionnel. Ordre = ordre de dessin.
R.SHAPES = {
    -- Plateau de la table (base = toujours dessine, meme sous la texture)
    { q = { -125, -15, 125, -15, 125, 485, -125, 485 }, col = "STEEL", base = true },
    -- Tete et cou
    { c = { 0, 30, 26 }, col = "SKIN" },
    { q = { -10, 52, 10, 52, 10, 72, -10, 72 }, col = "SKIN" },
    -- Torse et bassin
    { q = { -62, 70, 62, 70, 48, 250, -48, 250 }, col = "SKIN" },
    { q = { -48, 250, 48, 250, 56, 290, -56, 290 }, col = "SKIN" },
    -- Bras et mains
    { q = { -62, 72, -78, 80, -92, 285, -74, 285 }, col = "SKIN" },
    { q = { 62, 72, 78, 80, 92, 285, 74, 285 }, col = "SKIN" },
    { c = { -83, 295, 11 }, col = "SKIN" },
    { c = { 83, 295, 11 }, col = "SKIN" },
    -- Jambes et pieds
    { q = { -56, 290, -4, 290, -14, 465, -40, 465 }, col = "SKIN" },
    { q = { 4, 290, 56, 290, 40, 465, 14, 465 }, col = "SKIN" },
    { c = { -27, 470, 12 }, col = "SKIN" },
    { c = { 27, 470, 12 }, col = "SKIN" },
    -- Reperes anatomiques discrets
    { q = { -50, 80, -6, 92, -6, 95, -50, 83 }, col = "SKIN_DARK", a = 0.5 },
    { q = { 50, 80, 6, 92, 6, 95, 50, 83 }, col = "SKIN_DARK", a = 0.5 },
    { c = { -26, 150, 2.5 }, col = "SKIN_DARK", a = 0.8 },
    { c = { 26, 150, 2.5 }, col = "SKIN_DARK", a = 0.8 },
    { c = { 0, 215, 2.5 }, col = "SKIN_DARK", a = 0.9 },
};

--------------------------------------------------------------
-- Conversion : "ui" doit avoir offX, offY et scale
-- (ecran = off + corps * scale).
--------------------------------------------------------------

function R.toScreen(ui, x, y)
    return ui.offX + x * ui.scale, ui.offY + y * ui.scale;
end

function R.fillQuad(ui, pts, c, a)
    local x1, y1 = R.toScreen(ui, pts[1], pts[2]);
    local x2, y2 = R.toScreen(ui, pts[3], pts[4]);
    local x3, y3 = R.toScreen(ui, pts[5], pts[6]);
    local x4, y4 = R.toScreen(ui, pts[7], pts[8]);
    ui:drawPolygon(nil, x1, y1, x2, y2, x3, y3, x4, y4, c.r, c.g, c.b, a or 1);
end

function R.fillCircleScreen(ui, cx, cy, radius, c, a)
    local steps = 20;
    local prevX = cx + radius;
    local prevY = cy;
    for i = 1, steps do
        local ang = (i / steps) * math.pi * 2;
        local x = cx + math.cos(ang) * radius;
        local y = cy + math.sin(ang) * radius;
        ui:drawPolygon(nil, cx, cy, prevX, prevY, x, y, x, y, c.r, c.g, c.b, a or 1);
        prevX = x;
        prevY = y;
    end
end

function R.fillCircle(ui, def, c, a)
    local sx, sy = R.toScreen(ui, def[1], def[2]);
    R.fillCircleScreen(ui, sx, sy, def[3] * ui.scale, c, a);
end

--------------------------------------------------------------
-- Dessin
--------------------------------------------------------------

-- La texture n'est cherchee qu'une fois (pas a chaque image).
R.textureChecked = false;
R.texture = nil;

function R.getTexture()
    if not R.textureChecked then
        R.textureChecked = true;
        if R.TEXTURE_PATH then
            R.texture = getTexture(R.TEXTURE_PATH);
        end
    end
    return R.texture;
end

function R.drawShape(ui, shape)
    local c = R[shape.col];
    if shape.q then
        R.fillQuad(ui, shape.q, c, shape.a);
    elseif shape.c then
        R.fillCircle(ui, shape.c, c, shape.a);
    end
end

-- base = true : uniquement les formes de base (table) ; false : uniquement le corps.
function R.drawShapes(ui, base)
    for _, shape in ipairs(R.SHAPES) do
        if (shape.base == true) == base then
            R.drawShape(ui, shape);
        end
    end
end

-- Dessine la table, puis la texture si elle existe (et si forceShapes
-- n'est pas demande), sinon les formes geometriques du corps.
function R.drawBody(ui, forceShapes)
    R.drawShapes(ui, true);
    local tex = nil;
    if not forceShapes then
        tex = R.getTexture();
    end
    if tex then
        local x, y = R.toScreen(ui, R.CANVAS.x1, R.CANVAS.y1);
        local w = (R.CANVAS.x2 - R.CANVAS.x1) * ui.scale;
        local h = (R.CANVAS.y2 - R.CANVAS.y1) * ui.scale;
        ui:drawTextureScaled(tex, x, y, w, h, 1, 1, 1, 1);
        return;
    end
    R.drawShapes(ui, false);
end

--------------------------------------------------------------
-- Modele 3D du cadavre
--------------------------------------------------------------

require "ISUI/ISUI3DModel";

-- Composant 3D : pas de rotation a la souris, option "figer", et clics
-- renvoyes au panneau parent (forwardTo) pour que le mini-jeu les recoive.
TCA_Model3D = ISUI3DModel:derive("TCA_Model3D");

function TCA_Model3D:prerender()
    ISUIElement.prerender(self);
    if self.javaObject then
        self.javaObject:setAnimate(not self.frozen);
    end
end

function TCA_Model3D:onMouseDown(x, y)
    if self.forwardTo then
        return self.forwardTo:onMouseDown(x + self:getX(), y + self:getY());
    end
    return false;
end

function TCA_Model3D:onMouseMove(dx, dy)
    return false;
end

function TCA_Model3D:onMouseUp(x, y)
    if self.forwardTo then
        return self.forwardTo:onMouseUp(x + self:getX(), y + self:getY());
    end
    return false;
end

function TCA_Model3D:onMouseUpOutside(x, y)
    if self.forwardTo then
        return self.forwardTo:onMouseUpOutside(x + self:getX(), y + self:getY());
    end
    return false;
end

-- Utiliser le modele 3D dans le mini-jeu (sinon texture ou formes).
R.USE_MODEL = true;

-- Recopie l'apparence du cadavre dans une fiche de survivant temporaire
-- (le composant 3D attend un personnage ou une fiche, pas un cadavre).
function R.buildDescFromBody(body)
    local desc = SurvivorFactory.CreateSurvivor();
    desc:setFemale(body:isFemale());
    desc:getWornItems():clear();
    local src = body:getHumanVisual();
    local hv = desc:getHumanVisual();
    hv:copyFrom(src);
    -- Force le nom exact de la texture (peau de zombie et niveau de pourriture compris).
    hv:setSkinTextureName(src:getSkinTexture());
    return desc;
end

-- Cree le composant 3D (ajoute comme enfant de "parent").
function R.createModel(parent, x, y, w, h)
    local model = TCA_Model3D:new(x, y, w, h);
    model:initialise();
    model:instantiate();
    model.frozen = false;
    parent:addChild(model);
    model:setIsometric(false);
    model:setDirection(IsoDirections.S);
    return model;
end

-- Donne l'apparence et la pose au modele. Le moteur n'applique le jeu
-- d'animations qu'au moment ou l'apparence est donnee : jeu et etat AVANT
-- setSurvivorDesc. La pose d'autopsie reste figee (pas de transition auto).
function R.applyAppearance(model, desc, usePose)
    if usePose then
        model.frozen = true;
    end
    model.javaObject:setAnimate(not model.frozen);
    if usePose then
        model:setAnimSetName(R.POSE_ANIMSET);
        model:setState(R.POSE_STATE);
    else
        model:setAnimSetName(R.DEFAULT_ANIMSET);
        model:setState(R.DEFAULT_STATE);
    end
    if desc then
        model:setSurvivorDesc(desc);
    end
end

--------------------------------------------------------------
-- Camera du modele 3D
--
-- Le composant affiche H * sqrt(2048) / (2 * (25 - zoom)) pixels par unite
-- de modele (vue de face, projection orthographique), le point y = 0 du
-- monde etant au centre du composant. Le calage de reference a ete fait
-- sur le canevas 260 x 510 a l'echelle 1 (MODEL_ZOOM / MODEL_X / MODEL_Y).
-- On en deduit zoom et decalages pour n'importe quel cadrage "ui"
-- (offX, offY, scale) et n'importe quelle taille de composant.
--------------------------------------------------------------

R.CAMERA_BASE_SIZE = 25;
R.CAMERA_FACTOR = math.sqrt(2048);

-- Pixels de reference (= unites corps) par unite de modele.
function R.getReferencePixelsPerUnit()
    local refH = R.CANVAS.y2 - R.CANVAS.y1;
    return refH * R.CAMERA_FACTOR / (2 * (R.CAMERA_BASE_SIZE - R.MODEL_ZOOM));
end

-- Renvoie zoom, decalage X, decalage Y pour un composant place en
-- (x, y, w, h) dans "ui".
function R.computeCamera(ui, x, y, w, h)
    local sRef = R.getReferencePixelsPerUnit();
    local size = h * R.CAMERA_FACTOR / (2 * ui.scale * sRef);
    local zoom = R.CAMERA_BASE_SIZE - size;

    -- Point du corps qui doit se trouver au centre du composant.
    local bcx = (x + w / 2 - ui.offX) / ui.scale;
    local bcy = (y + h / 2 - ui.offY) / ui.scale;
    -- Point du corps au centre du canevas de reference.
    local rcx = (R.CANVAS.x1 + R.CANVAS.x2) / 2;
    local rcy = (R.CANVAS.y1 + R.CANVAS.y2) / 2;

    local offY = R.MODEL_Y - (rcy - bcy) / sRef;
    local offX = R.MODEL_X + (bcx - rcx) / sRef;
    -- Le moteur remplace un decalage Y nul par -0.5 : on l'evite.
    if offY == 0 then
        offY = 0.000001;
    end
    return zoom, offX, offY;
end

function R.applyCamera(model, ui)
    local zoom, offX, offY = R.computeCamera(ui, model:getX(), model:getY(), model:getWidth(), model:getHeight());
    model:setZoom(zoom);
    model:setXOffset(offX);
    model:setYOffset(offY);
end
