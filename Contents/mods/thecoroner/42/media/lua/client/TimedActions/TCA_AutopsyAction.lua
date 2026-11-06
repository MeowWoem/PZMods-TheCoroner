--***********************************************************
--**  Action locale : le personnage est penche sur la      **
--**  table pendant toute la duree du mini-jeu.            **
--**  Si l'action est interrompue (zombie, mouvement...),  **
--**  le mini-jeu se ferme et le resultat partiel est      **
--**  applique.                                            **
--***********************************************************

require "TimedActions/ISBaseTimedAction";
require "TCA_Shared";
require "TCA_Autopsy";

TCA_AutopsyAction = ISBaseTimedAction:derive("TCA_AutopsyAction");

function TCA_AutopsyAction:isValid()
    if not self.tableObject or not self.tableObject:getSquare() then
        return false;
    end
    local body = TCA.findBodyOnTable(self.tableObject);
    if not body then
        return false;
    end
    if TCA.Autopsy.getBlockingClothing(body) then
        return false;
    end
    -- Outil de l'etape ou en est le cadavre (scalpel, pince, scie...).
    -- Les outils des etapes suivantes sont verifies dans le mini-jeu.
    local stage = TCA.Autopsy.getStage(body);
    if stage == "done" then
        return false;
    end
    return TCA.Autopsy.hasToolForStage(self.character, stage);
end

function TCA_AutopsyAction:waitToStart()
    self.character:faceThisObject(self.tableObject);
    return self.character:shouldBeTurning();
end

function TCA_AutopsyAction:update()
    self.character:faceThisObject(self.tableObject);
    self.character:setMetabolicTarget(Metabolics.LightWork);
    if self.ui and self.ui.finished then
        self:forceComplete();
    end
end

function TCA_AutopsyAction:start()
    self:setActionAnim("Loot");
    self:setAnimVariable("LootPosition", "Mid");
    self.ui = TCA_AutopsyUI.open(self.character, self.tableObject);
end

function TCA_AutopsyAction:closeUI()
    if not self.ui then
        return;
    end
    local result = self.ui:collectResult();
    self.ui:closeSilently();
    self.ui = nil;
    if result.advanced then
        -- Ajoute au tick suivant : pendant stop(), la file est videe juste apres.
        TCA_Client.queueNextTick(TCA_AutopsyResultAction:new(self.character, self.tableObject, result.segIndex, result.segProgress, result.accuracy, result.paths, result.opened, result.ribs));
    end
end

function TCA_AutopsyAction:stop()
    self:closeUI();
    ISBaseTimedAction.stop(self);
end

function TCA_AutopsyAction:perform()
    self:closeUI();
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self);
end

function TCA_AutopsyAction:new(character, tableObject)
    local o = ISBaseTimedAction.new(self, character);
    o.character = character;
    o.tableObject = tableObject;
    o.maxTime = -1;
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.stopOnAim = true;
    return o;
end
