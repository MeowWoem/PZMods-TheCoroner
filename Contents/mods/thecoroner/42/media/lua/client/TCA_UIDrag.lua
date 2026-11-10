TCA_UIDrag = TCA_UIDrag or {};

local G = TCA_UIDrag;

G.saved = G.saved or {};
G.MARGIN = 20;

function G.begin(ui, x, y)
    if y >= ui.viewY then
        return false;
    end
    local drag = {};
    drag.mouseX = getMouseX();
    drag.mouseY = getMouseY();
    drag.x = ui:getX();
    drag.y = ui:getY();
    ui.windowDrag = drag;
    return true;
end

function G.clampX(ui, x)
    local maxX = getCore():getScreenWidth() - G.MARGIN;
    local minX = G.MARGIN - ui.width;
    return math.max(minX, math.min(maxX, x));
end

function G.clampY(ui, y)
    local maxY = getCore():getScreenHeight() - G.MARGIN;
    return math.max(0, math.min(maxY, y));
end

function G.update(ui)
    local drag = ui.windowDrag;
    if not drag then
        return;
    end
    ui:setX(G.clampX(ui, drag.x + getMouseX() - drag.mouseX));
    ui:setY(G.clampY(ui, drag.y + getMouseY() - drag.mouseY));
end

function G.finish(ui, key)
    if not ui.windowDrag then
        return false;
    end
    ui.windowDrag = nil;
    local pos = {};
    pos.x = ui:getX();
    pos.y = ui:getY();
    G.saved[key] = pos;
    return true;
end

function G.restore(ui, key)
    local pos = G.saved[key];
    if not pos then
        return;
    end
    ui:setX(G.clampX(ui, pos.x));
    ui:setY(G.clampY(ui, pos.y));
end
