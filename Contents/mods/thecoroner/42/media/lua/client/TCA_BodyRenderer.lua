TCA_BodyRenderer = TCA_BodyRenderer or {};
local R = TCA_BodyRenderer;

R.CANVAS = { x1 = -130, y1 = -20, x2 = 130, y2 = 490 };

R.TEXTURE_PATH = "media/textures/TCA_Body.png";

R.MODEL_ZOOM = 0;
R.MODEL_X = 0;
R.MODEL_Y = -0.46;

R.POSE_ANIMSET = "player-avatar";
R.POSE_STATE = "tca_autopsypose";
R.DEFAULT_ANIMSET = "player-avatar";
R.DEFAULT_STATE = "idle";

R.SKIN = { r = 0.55, g = 0.60, b = 0.50 };
R.SKIN_DARK = { r = 0.42, g = 0.47, b = 0.38 };
R.STEEL = { r = 0.42, g = 0.45, b = 0.48 };

R.SHAPES = {
    { q = { -125, -15, 125, -15, 125, 485, -125, 485 }, col = "STEEL", base = true },
    { c = { 0, 30, 26 }, col = "SKIN" },
    { q = { -10, 52, 10, 52, 10, 72, -10, 72 }, col = "SKIN" },
    { q = { -62, 70, 62, 70, 48, 250, -48, 250 }, col = "SKIN" },
    { q = { -48, 250, 48, 250, 56, 290, -56, 290 }, col = "SKIN" },
    { q = { -62, 72, -78, 80, -92, 285, -74, 285 }, col = "SKIN" },
    { q = { 62, 72, 78, 80, 92, 285, 74, 285 }, col = "SKIN" },
    { c = { -83, 295, 11 }, col = "SKIN" },
    { c = { 83, 295, 11 }, col = "SKIN" },
    { q = { -56, 290, -4, 290, -14, 465, -40, 465 }, col = "SKIN" },
    { q = { 4, 290, 56, 290, 40, 465, 14, 465 }, col = "SKIN" },
    { c = { -27, 470, 12 }, col = "SKIN" },
    { c = { 27, 470, 12 }, col = "SKIN" },
    { q = { -50, 80, -6, 92, -6, 95, -50, 83 }, col = "SKIN_DARK", a = 0.5 },
    { q = { 50, 80, 6, 92, 6, 95, 50, 83 }, col = "SKIN_DARK", a = 0.5 },
    { c = { -26, 150, 2.5 }, col = "SKIN_DARK", a = 0.8 },
    { c = { 26, 150, 2.5 }, col = "SKIN_DARK", a = 0.8 },
    { c = { 0, 215, 2.5 }, col = "SKIN_DARK", a = 0.9 },
};

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

function R.drawShapes(ui, base)
    for _, shape in ipairs(R.SHAPES) do
        if (shape.base == true) == base then
            R.drawShape(ui, shape);
        end
    end
end

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

require "ISUI/ISUI3DModel";

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

R.USE_MODEL = true;

function R.copyKeptWornItems(body, desc)
    if not TCA or not TCA.Wounds or not TCA.Wounds.shouldKeepWornItem or not body.getWornItems then
        return;
    end
    local worn = body:getWornItems();
    if not worn then
        return;
    end
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i);
        if item and TCA.Wounds.shouldKeepWornItem(item) then
            local location = worn:getLocation(item);
            if location then
                desc:setWornItem(location, item);
            end
        end
    end
end

function R.buildDescFromBody(body)
    local desc = SurvivorFactory.CreateSurvivor();
    desc:setFemale(body:isFemale());
    desc:getWornItems():clear();
    local src = body:getHumanVisual();
    local hv = desc:getHumanVisual();
    hv:copyFrom(src);
    hv:setSkinTextureName(src:getSkinTexture());
    R.copyKeptWornItems(body, desc);
    return desc;
end

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

R.CAMERA_BASE_SIZE = 25;
R.CAMERA_FACTOR = math.sqrt(2048);

function R.getReferencePixelsPerUnit()
    local refH = R.CANVAS.y2 - R.CANVAS.y1;
    return refH * R.CAMERA_FACTOR / (2 * (R.CAMERA_BASE_SIZE - R.MODEL_ZOOM));
end

function R.computeCamera(ui, x, y, w, h)
    local sRef = R.getReferencePixelsPerUnit();
    local size = h * R.CAMERA_FACTOR / (2 * ui.scale * sRef);
    local zoom = R.CAMERA_BASE_SIZE - size;

    local bcx = (x + w / 2 - ui.offX) / ui.scale;
    local bcy = (y + h / 2 - ui.offY) / ui.scale;
    local rcx = (R.CANVAS.x1 + R.CANVAS.x2) / 2;
    local rcy = (R.CANVAS.y1 + R.CANVAS.y2) / 2;

    local offY = R.MODEL_Y - (rcy - bcy) / sRef;
    local offX = R.MODEL_X + (bcx - rcx) / sRef;
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
