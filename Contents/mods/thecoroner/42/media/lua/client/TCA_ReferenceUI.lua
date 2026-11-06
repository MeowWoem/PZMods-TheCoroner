--***********************************************************
--**  Debug : image de reference du corps a l'echelle 1:1  **
--**                                                       **
--**  Trois sources affichables sur le canevas 260 x 510 : **
--**  - Formes : les formes geometriques ;                 **
--**  - Texture : media/textures/TCA_Body.png ;            **
--**  - 3D : le modele 3D du cadavre pose sur la table     **
--**    (prototype), avec reglages de calage.              **
--**                                                       **
--**  Fond magenta uni : une capture recadree sur le       **
--**  canevas donne exactement l'image a reproduire.       **
--***********************************************************

require "ISUI/ISPanel";
require "ISUI/ISButton";
require "ISUI/ISUI3DModel";
require "TCA_Shared";
require "TCA_Autopsy";
require "TCA_BodyRenderer";
require "TCA_AutopsyUI";

--------------------------------------------------------------
-- Panneau
--------------------------------------------------------------

TCA_ReferenceUI = ISPanel:derive("TCA_ReferenceUI");

TCA_ReferenceUI.MARGIN = 20;
TCA_ReferenceUI.SIDE_W = 150;
TCA_ReferenceUI.MAGENTA = { r = 1, g = 0, b = 1 };
TCA_ReferenceUI.MODES = { "shapes", "texture", "model" };

-- Pas des reglages du modele 3D (valeurs de depart : TCA_BodyRenderer.MODEL_*).
TCA_ReferenceUI.ZOOM_STEP = 0.5;
TCA_ReferenceUI.OFFSET_STEP = 0.01;

local GRID = { r = 0, g = 0, b = 0 };
local ORIGIN = { r = 1, g = 0.1, b = 0.1 };
local INCISION = { r = 1, g = 0.9, b = 0.1 };
local VIEW = { r = 0.1, g = 0.9, b = 1 };

local function round(v, step)
    return math.floor(v / step + 0.5) * step;
end

function TCA_ReferenceUI:initialise()
    ISPanel.initialise(self);
    local c = TCA_BodyRenderer.CANVAS;
    self.canvasW = c.x2 - c.x1;
    self.canvasH = c.y2 - c.y1;
    local smallH = getTextManager():getFontHeight(UIFont.Small);
    local titleH = getTextManager():getFontHeight(UIFont.Medium);
    self.infoY = 10 + titleH + 4;
    self.canvasX = TCA_ReferenceUI.MARGIN;
    self.canvasY = self.infoY + smallH * 3 + 10;
    -- Echelle 1 : un pixel de l'image = un pixel a l'ecran.
    self.scale = 1;
    self.offX = self.canvasX - c.x1;
    self.offY = self.canvasY - c.y1;
    self.showGuides = true;
    self.modeIndex = 1;
    self.modelZoom = TCA_BodyRenderer.MODEL_ZOOM;
    self.modelX = TCA_BodyRenderer.MODEL_X;
    self.modelY = TCA_BodyRenderer.MODEL_Y;
    self.usePose = true;
    self.bodyInfo = "";
end

function TCA_ReferenceUI:addButton(x, y, w, title, onClick)
    local btn = ISButton:new(x, y, w, 22, title, self, onClick);
    btn:initialise();
    btn:instantiate();
    self:addChild(btn);
    return btn;
end

function TCA_ReferenceUI:createChildren()
    ISPanel.createChildren(self);

    -- Modele 3D place exactement sur le canevas (cache hors mode 3D).
    self.model = TCA_BodyRenderer.createModel(self, self.canvasX, self.canvasY, self.canvasW, self.canvasH);
    self.model:setVisible(false);
    self:applyModelSettings();

    local x = self.canvasX + self.canvasW + TCA_ReferenceUI.MARGIN;
    local w = TCA_ReferenceUI.SIDE_W;
    local small = 30;
    local y = self.canvasY;

    self.modeButton = self:addButton(x, y, w, "", TCA_ReferenceUI.onCycleMode);
    y = y + 28;
    self.guidesButton = self:addButton(x, y, w, "", TCA_ReferenceUI.onToggleGuides);
    y = y + 40;

    -- Reglages du modele 3D : libelle a gauche, "-" et "+" a droite.
    self.rowZoomY = y;
    self.zoomMinus = self:addButton(x + w - small * 2 - 4, y, small, "-", TCA_ReferenceUI.onZoomMinus);
    self.zoomPlus = self:addButton(x + w - small, y, small, "+", TCA_ReferenceUI.onZoomPlus);
    y = y + 26;
    self.rowYY = y;
    self.yMinus = self:addButton(x + w - small * 2 - 4, y, small, "-", TCA_ReferenceUI.onYMinus);
    self.yPlus = self:addButton(x + w - small, y, small, "+", TCA_ReferenceUI.onYPlus);
    y = y + 26;
    self.rowXY = y;
    self.xMinus = self:addButton(x + w - small * 2 - 4, y, small, "-", TCA_ReferenceUI.onXMinus);
    self.xPlus = self:addButton(x + w - small, y, small, "+", TCA_ReferenceUI.onXPlus);
    y = y + 34;
    self.freezeButton = self:addButton(x, y, w, "", TCA_ReferenceUI.onToggleFreeze);
    y = y + 28;
    self.poseButton = self:addButton(x, y, w, "", TCA_ReferenceUI.onTogglePose);
    y = y + 28;
    self.reloadButton = self:addButton(x, y, w, getText("IGUI_TCA_RefReload"), TCA_ReferenceUI.onReloadBody);

    self.closeButton = self:addButton(x, self.canvasY + self.canvasH - 22, w, getText("IGUI_TCA_RefClose"), TCA_ReferenceUI.onClose);

    self.modelControls = { self.zoomMinus, self.zoomPlus, self.yMinus, self.yPlus, self.xMinus, self.xPlus, self.freezeButton, self.poseButton, self.reloadButton };
    self:loadBody();
    self:updateButtons();
end

function TCA_ReferenceUI:getMode()
    return TCA_ReferenceUI.MODES[self.modeIndex];
end

function TCA_ReferenceUI:updateButtons()
    local mode = self:getMode();
    if mode == "shapes" then
        self.modeButton:setTitle(getText("IGUI_TCA_RefShapes"));
    elseif mode == "texture" then
        self.modeButton:setTitle(getText("IGUI_TCA_RefTexture"));
    else
        self.modeButton:setTitle(getText("IGUI_TCA_RefModel"));
    end
    if self.showGuides then
        self.guidesButton:setTitle(getText("IGUI_TCA_RefGuidesOn"));
    else
        self.guidesButton:setTitle(getText("IGUI_TCA_RefGuidesOff"));
    end
    if self.model.frozen then
        self.freezeButton:setTitle(getText("IGUI_TCA_RefAnimate"));
    else
        self.freezeButton:setTitle(getText("IGUI_TCA_RefFreeze"));
    end
    if self.usePose then
        self.poseButton:setTitle(getText("IGUI_TCA_RefPoseAutopsy"));
    else
        self.poseButton:setTitle(getText("IGUI_TCA_RefPoseIdle"));
    end
    local isModel = mode == "model";
    self.model:setVisible(isModel);
    for _, btn in ipairs(self.modelControls) do
        btn:setVisible(isModel);
    end
end

--------------------------------------------------------------
-- Modele 3D : apparence du cadavre pose sur la table
--------------------------------------------------------------

function TCA_ReferenceUI:loadBody()
    local body = nil;
    if self.tableObject then
        body = TCA.findBodyOnTable(self.tableObject);
    end
    local desc = nil;
    if body then
        desc = TCA_BodyRenderer.buildDescFromBody(body);
        local hv = body:getHumanVisual();
        self.bodyInfo = getText("IGUI_TCA_RefBodyInfo", tostring(hv:getSkinTexture()), tostring(hv:getHairModel()));
    else
        desc = SurvivorFactory.CreateSurvivor();
        desc:getWornItems():clear();
        self.bodyInfo = getText("IGUI_TCA_RefNoBody");
    end
    self.desc = desc;
    self:applyPose();
end

-- Pose d'autopsie (animation du mod) ou pose de repos vanilla.
function TCA_ReferenceUI:applyPose()
    TCA_BodyRenderer.applyAppearance(self.model, self.desc, self.usePose);
end

function TCA_ReferenceUI:applyModelSettings()
    self.model:setZoom(self.modelZoom);
    self.model:setXOffset(self.modelX);
    self.model:setYOffset(self.modelY);
end

--------------------------------------------------------------
-- Boutons
--------------------------------------------------------------

function TCA_ReferenceUI:onCycleMode()
    self.modeIndex = self.modeIndex + 1;
    if self.modeIndex > #TCA_ReferenceUI.MODES then
        self.modeIndex = 1;
    end
    -- Permet de recharger une texture ajoutee ou modifiee entre-temps.
    TCA_BodyRenderer.textureChecked = false;
    self:updateButtons();
end

function TCA_ReferenceUI:onToggleGuides()
    self.showGuides = not self.showGuides;
    self:updateButtons();
end

function TCA_ReferenceUI:onToggleFreeze()
    if self.usePose then
        -- La pose d'autopsie reste toujours figee.
        return;
    end
    self.model.frozen = not self.model.frozen;
    self:updateButtons();
end

function TCA_ReferenceUI:onTogglePose()
    self.usePose = not self.usePose;
    self:applyPose();
    self:updateButtons();
end

function TCA_ReferenceUI:onReloadBody()
    self:loadBody();
end

function TCA_ReferenceUI:onZoomMinus()
    self.modelZoom = round(self.modelZoom - TCA_ReferenceUI.ZOOM_STEP, 0.01);
    self:applyModelSettings();
end

function TCA_ReferenceUI:onZoomPlus()
    self.modelZoom = round(self.modelZoom + TCA_ReferenceUI.ZOOM_STEP, 0.01);
    self:applyModelSettings();
end

function TCA_ReferenceUI:onYMinus()
    self.modelY = round(self.modelY - TCA_ReferenceUI.OFFSET_STEP, 0.001);
    self:applyModelSettings();
end

function TCA_ReferenceUI:onYPlus()
    self.modelY = round(self.modelY + TCA_ReferenceUI.OFFSET_STEP, 0.001);
    self:applyModelSettings();
end

function TCA_ReferenceUI:onXMinus()
    self.modelX = round(self.modelX - TCA_ReferenceUI.OFFSET_STEP, 0.001);
    self:applyModelSettings();
end

function TCA_ReferenceUI:onXPlus()
    self.modelX = round(self.modelX + TCA_ReferenceUI.OFFSET_STEP, 0.001);
    self:applyModelSettings();
end

function TCA_ReferenceUI:onClose()
    self:setVisible(false);
    self:removeFromUIManager();
    TCA_ReferenceUI.instance = nil;
end

--------------------------------------------------------------
-- Guides (grille, origine, incisions, cadrage du mini-jeu)
--------------------------------------------------------------

function TCA_ReferenceUI:drawRectLines(x1, y1, x2, y2, c, a)
    local sx1, sy1 = TCA_BodyRenderer.toScreen(self, x1, y1);
    local sx2, sy2 = TCA_BodyRenderer.toScreen(self, x2, y2);
    self:drawRectBorder(sx1, sy1, sx2 - sx1, sy2 - sy1, a, c.r, c.g, c.b);
end

function TCA_ReferenceUI:drawGuides()
    local c = TCA_BodyRenderer.CANVAS;

    -- Grille : tous les 10 px (fine) et 50 px (marquee), alignee sur l'origine.
    for x = math.ceil(c.x1 / 10) * 10, c.x2, 10 do
        local a = 0.12;
        if x % 50 == 0 then
            a = 0.3;
        end
        local sx, sy1 = TCA_BodyRenderer.toScreen(self, x, c.y1);
        self:drawRect(sx, sy1, 1, self.canvasH, a, GRID.r, GRID.g, GRID.b);
    end
    for y = math.ceil(c.y1 / 10) * 10, c.y2, 10 do
        local a = 0.12;
        if y % 50 == 0 then
            a = 0.3;
        end
        local sx1, sy = TCA_BodyRenderer.toScreen(self, c.x1, y);
        self:drawRect(sx1, sy, self.canvasW, 1, a, GRID.r, GRID.g, GRID.b);
    end

    -- Cadrage visible pendant l'incision en Y
    local v = TCA_AutopsyUI.VIEW_Y_INCISION;
    self:drawRectLines(v.x1, v.y1, v.x2, v.y2, VIEW, 0.9);

    -- Trace de l'incision en Y
    for _, seg in ipairs(TCA.Autopsy.INCISION_Y) do
        local ax, ay = TCA_BodyRenderer.toScreen(self, seg.ax, seg.ay);
        local bx, by = TCA_BodyRenderer.toScreen(self, seg.bx, seg.by);
        self:drawLine2(ax, ay, bx, by, 1, INCISION.r, INCISION.g, INCISION.b);
        self:drawRect(ax - 2, ay - 2, 5, 5, 1, INCISION.r, INCISION.g, INCISION.b);
        self:drawRect(bx - 2, by - 2, 5, 5, 1, INCISION.r, INCISION.g, INCISION.b);
    end

    -- Origine du corps (0, 0)
    local ox, oy = TCA_BodyRenderer.toScreen(self, 0, 0);
    self:drawRect(ox - 6, oy, 13, 1, 1, ORIGIN.r, ORIGIN.g, ORIGIN.b);
    self:drawRect(ox, oy - 6, 1, 13, 1, ORIGIN.r, ORIGIN.g, ORIGIN.b);
end

--------------------------------------------------------------
-- Rendu : fond + corps (prerender), modele 3D (enfant),
-- puis guides par-dessus tout (render).
--------------------------------------------------------------

function TCA_ReferenceUI:prerender()
    ISPanel.prerender(self);
    local c = TCA_BodyRenderer.CANVAS;
    local smallH = getTextManager():getFontHeight(UIFont.Small);

    self:drawText(getText("IGUI_TCA_RefTitle"), TCA_ReferenceUI.MARGIN, 10, 1, 1, 1, 1, UIFont.Medium);
    self:drawText(getText("IGUI_TCA_RefSize", self.canvasW, self.canvasH), TCA_ReferenceUI.MARGIN, self.infoY, 0.85, 0.85, 0.85, 1, UIFont.Small);
    self:drawText(getText("IGUI_TCA_RefOrigin", -c.x1, -c.y1), TCA_ReferenceUI.MARGIN, self.infoY + smallH, 0.85, 0.85, 0.85, 1, UIFont.Small);
    self:drawText(self.bodyInfo, TCA_ReferenceUI.MARGIN, self.infoY + smallH * 2, 0.7, 0.9, 1, 1, UIFont.Small);

    -- Fond magenta uni : facile a detourer dans Photoshop.
    local m = TCA_ReferenceUI.MAGENTA;
    self:drawRect(self.canvasX, self.canvasY, self.canvasW, self.canvasH, 1, m.r, m.g, m.b);

    local mode = self:getMode();
    if mode ~= "model" then
        self:setStencilRect(self.canvasX, self.canvasY, self.canvasW, self.canvasH);
        TCA_BodyRenderer.drawBody(self, mode == "shapes");
        self:clearStencilRect();
    else
        -- Libelles des reglages 3D (valeurs a me renvoyer une fois cale).
        local x = self.canvasX + self.canvasW + TCA_ReferenceUI.MARGIN;
        self:drawText(getText("IGUI_TCA_RefZoom", tostring(self.modelZoom)), x, self.rowZoomY + 3, 1, 1, 1, 1, UIFont.Small);
        self:drawText(getText("IGUI_TCA_RefOffY", tostring(self.modelY)), x, self.rowYY + 3, 1, 1, 1, 1, UIFont.Small);
        self:drawText(getText("IGUI_TCA_RefOffX", tostring(self.modelX)), x, self.rowXY + 3, 1, 1, 1, 1, UIFont.Small);
    end
end

function TCA_ReferenceUI:render()
    ISPanel.render(self);
    if self.showGuides then
        self:setStencilRect(self.canvasX, self.canvasY, self.canvasW, self.canvasH);
        self:drawGuides();
        self:clearStencilRect();
    end
    -- Cadre a l'exterieur du canevas (n'empiete pas sur l'image).
    self:drawRectBorder(self.canvasX - 1, self.canvasY - 1, self.canvasW + 2, self.canvasH + 2, 1, 1, 1, 1);
end

function TCA_ReferenceUI.open(tableObject)
    if TCA_ReferenceUI.instance then
        TCA_ReferenceUI.instance:onClose();
    end
    local c = TCA_BodyRenderer.CANVAS;
    local margin = TCA_ReferenceUI.MARGIN;
    local smallH = getTextManager():getFontHeight(UIFont.Small);
    local titleH = getTextManager():getFontHeight(UIFont.Medium);
    local w = margin + (c.x2 - c.x1) + margin + TCA_ReferenceUI.SIDE_W + margin;
    local h = 10 + titleH + 4 + smallH * 3 + 10 + (c.y2 - c.y1) + margin;
    -- Position entiere : indispensable pour un rendu pixel pour pixel.
    local x = math.floor((getCore():getScreenWidth() - w) / 2);
    local y = math.floor((getCore():getScreenHeight() - h) / 2);
    local ui = TCA_ReferenceUI:new(x, y, w, h, tableObject);
    ui:initialise();
    ui:instantiate();
    ui:addToUIManager();
    TCA_ReferenceUI.instance = ui;
    return ui;
end

function TCA_ReferenceUI:new(x, y, width, height, tableObject)
    local o = ISPanel.new(self, x, y, width, height);
    o.tableObject = tableObject;
    o.backgroundColor = { r = 0.08, g = 0.08, b = 0.09, a = 1 };
    o.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 };
    o.moveWithMouse = true;
    return o;
end
