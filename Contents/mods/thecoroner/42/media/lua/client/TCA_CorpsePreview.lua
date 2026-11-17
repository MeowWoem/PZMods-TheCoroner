require "ISUI/ISPanel";
require "ISUI/ISUI3DModel";
require "ISUI/ISToolTipInv";
require "TCA_UIScale";

TCA = TCA or {};
TCA.CorpsePreview = TCA.CorpsePreview or {};

local P = TCA.CorpsePreview;

P.BASE_W = 130;
P.BASE_H = 260;
P.GAP = 4;
P.PAD = 4;
P.HIDE_AFTER_MS = 150;
P.TURN_MS = 900;
P.ZOOM = -3;
P.Y_OFFSET = 0;
P.DIRECTIONS = { IsoDirections.S, IsoDirections.SW, IsoDirections.W, IsoDirections.NW, IsoDirections.N, IsoDirections.NE, IsoDirections.E, IsoDirections.SE };

TCA_CorpsePreviewPanel = ISPanel:derive("TCA_CorpsePreviewPanel");

function TCA_CorpsePreviewPanel:prerender()
    if getTimestampMs() - P.lastSeen > P.HIDE_AFTER_MS then
        self:setVisible(false);
        return;
    end
    ISPanel.prerender(self);
    local now = getTimestampMs();
    if now - (self.lastTurn or 0) >= P.TURN_MS then
        self.lastTurn = now;
        self.turn = (self.turn % #P.DIRECTIONS) + 1;
        self.model:setDirection(P.DIRECTIONS[self.turn]);
    end
end

function TCA_CorpsePreviewPanel:new(x, y, w, h)
    local o = ISPanel.new(self, x, y, w, h);
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 };
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 };
    o.turn = 1;
    o.lastTurn = 0;
    return o;
end

P.lastSeen = 0;

function P.isHumanCorpse(item)
    return item ~= nil and instanceof(item, "InventoryItem") and item:isHumanCorpse() and item:getByteData() ~= nil;
end

function P.buildDesc(item)
    local body = item:loadCorpseFromByteData(nil);
    if not body then
        return nil;
    end
    local desc = SurvivorFactory.CreateSurvivor();
    desc:setFemale(body:isFemale());
    desc:getWornItems():clear();
    local src = body:getHumanVisual();
    local hv = desc:getHumanVisual();
    hv:copyFrom(src);
    hv:setSkinTextureName(src:getSkinTexture());
    local worn = body:getWornItems();
    if worn then
        for i = 0, worn:size() - 1 do
            local wornItem = worn:getItemByIndex(i);
            local location = wornItem and worn:getLocation(wornItem);
            if location then
                desc:setWornItem(location, wornItem);
            end
        end
    end
    return desc;
end

function P.getPanel()
    local k = TCA_UIScale.get(P.BASE_W, P.BASE_H);
    local w = math.floor(P.BASE_W * k);
    local h = math.floor(P.BASE_H * k);
    if P.panel and P.panelK == k then
        return P.panel;
    end
    if P.panel then
        P.panel:removeFromUIManager();
    end
    local pad = math.floor(P.PAD * k);
    local panel = TCA_CorpsePreviewPanel:new(0, 0, w, h);
    panel:initialise();
    panel:instantiate();
    panel:setAlwaysOnTop(true);
    local model = ISUI3DModel:new(pad, pad, w - pad * 2, h - pad * 2);
    model:initialise();
    model:instantiate();
    model:setState("idle");
    model:setDirection(IsoDirections.S);
    model:setIsometric(false);
    model:setZoom(P.ZOOM);
    model:setYOffset(P.Y_OFFSET);
    panel:addChild(model);
    panel.model = model;
    panel:addToUIManager();
    panel:setVisible(false);
    P.panel = panel;
    P.panelK = k;
    P.cacheItem = nil;
    return panel;
end

function P.place(panel, tooltip)
    local screenW = getCore():getScreenWidth();
    local screenH = getCore():getScreenHeight();
    local x = tooltip:getX() + tooltip:getWidth() + P.GAP;
    if x + panel:getWidth() > screenW then
        x = tooltip:getX() - panel:getWidth() - P.GAP;
    end
    local y = tooltip:getY();
    if y + panel:getHeight() > screenH then
        y = screenH - panel:getHeight();
    end
    panel:setX(math.max(0, x));
    panel:setY(math.max(0, y));
end

function P.show(tooltip, item)
    local panel = P.getPanel();
    if P.cacheItem ~= item then
        local desc = P.buildDesc(item);
        if not desc then
            return;
        end
        P.cacheItem = item;
        panel.model:setSurvivorDesc(desc);
        panel.turn = 1;
        panel.lastTurn = getTimestampMs();
        panel.model:setDirection(IsoDirections.S);
    end
    P.lastSeen = getTimestampMs();
    P.place(panel, tooltip);
    if not panel:isVisible() then
        panel:setVisible(true);
    end
    panel:bringToTop();
end

function P.render(self)
    P.originalRender(self);
    if not TCA_UIScale.isCorpsePreviewEnabled() then
        return;
    end
    local item = self.item;
    if P.isHumanCorpse(item) then
        P.show(self, item);
    end
end

function P.hook()
    if P.originalRender ~= nil then
        return;
    end
    local original = ISToolTipInv.render;
    if type(original) ~= "function" then
        return;
    end
    P.originalRender = original;
    ISToolTipInv.render = P.render;
end

Events.OnGameStart.Add(P.hook);
