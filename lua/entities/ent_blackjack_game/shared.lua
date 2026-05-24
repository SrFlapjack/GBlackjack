//Basics//

ENT.Type        = "anim"
ENT.PrintName   = "GBlackjack Table"
ENT.Spawnable   = true
ENT.Category    = "Fun + Games"
ENT.Base        = "base_gmodentity"

//Blackjack info//

ENT.intermission = 5

ENT.potModel = {
    [0] = {mdl = Model("models/items/currencypack_small.mdl"), val = 100},
    [1] = {mdl = Model("models/items/currencypack_medium.mdl"), val = 1000},
    [2] = {mdl = Model("models/items/currencypack_large.mdl"), val = 100000}
}

ENT.communityDeck = {}
ENT.players = {}

//Functions//

function ENT:getPlayerKey(p)
    for k,v in pairs(self.players or {}) do
        if v.ind and Entity(v.ind) == p then return k end
    end

    return nil
end

function ENT:getPlayersAmount()
    local count = 0

    for k,v in pairs(self.players or {}) do
        if !v.bot then count = count + 1 end
    end

    return count
end

function ENT:getBotsAmount()
    local count = 0

    for k,v in pairs(self.players or {}) do
        if v.bot then count = count + 1 end
    end

    return count
end

function ENT:SetupDataTables()
    //Configurables
    self:NetworkVar("Int", 0, "GameType")
    self:NetworkVar("Int", 1, "MaxPlayers")
    self:NetworkVar("Int", 2, "BetType")
    self:NetworkVar("Float", 0, "EntryBet")
    self:NetworkVar("Float", 1, "StartValue")
    self:NetworkVar("Bool", 0, "BotsPlaceholder")
    self:NetworkVar("Int", 3, "Bots")

    //Match important stuff
    self:NetworkVar("Int", 4, "GameState")
    self:NetworkVar("Float", 2, "Pot")
    self:NetworkVar("Float", 3, "Bet")
    self:NetworkVar("Bool", 1, "Check")

    //Players related stuff
    self:NetworkVar("Int", 5, "Dealer")
    self:NetworkVar("Int", 6, "Turn")
    self:NetworkVar("Int", 7, "Winner")
    self:NetworkVar("Int", 8, "BlackjackPayout")
    self:NetworkVar("Bool", 2, "DealerHitSoft17")
    self:NetworkVar("Bool", 3, "AllowDouble")
    self:NetworkVar("String", 0, "DealerMessage")

    self:NetworkVarNotify("GameState", function(ent,name,old,new)
        if new == 0 then
            timer.Create("gblackjack_intermission" .. self:EntIndex(), self.intermission, 1, function()
                if SERVER and IsValid(self) and #self.players > 0 then
                    self:SetGameState(1)
                    gBlackjack.gameType[self:GetGameType()].states[1].func(self)
                end
            end)
        elseif old == 0 and new == -1 then
            timer.Remove("gblackjack_intermission" .. self:EntIndex())
        end

        if CLIENT then
            if old < 1 and new > 0 then
                if IsValid(self.deckPot) then
                    self.deckPot:SetModel(gBlackjack.betType[self:GetBetType()].models[1].mdl)
                    self.deckPot:SetModelScale(gBlackjack.betType[self:GetBetType()].models[1].scale)
                end
                if self.dealer == NULL then
                    self.dealer = ClientsideModel("models/cards/chip.mdl", RENDERGROUP_BOTH)
                    self.dealer:SetParent(self)
                    self.dealer:SetLocalPos(Vector(0,0,0))
                end
            elseif old > 0 and new < 1 then
                if IsValid(self.dealer) then
                    self.dealer:Remove()
                    self.dealer = NULL
                end
                if IsValid(self.deckPot) then
                    self.deckPot:SetModel("models/cards/stack.mdl")
                    self.deckPot:SetModelScale(1.75)
                end
                self.localDeck = {}
                self.communityDeck = {}
            end
        end
    end)

    if CLIENT then
        self:NetworkVarNotify("Pot", function(ent, name, old, new)
            for i = 1, #gBlackjack.betType[self:GetBetType()].models do
                if new < gBlackjack.betType[self:GetBetType()].models[i].val and IsValid(self.deckPot) then
                    self.deckPot:SetModel(gBlackjack.betType[self:GetBetType()].models[i].mdl)
                    self.deckPot:SetModelScale(gBlackjack.betType[self:GetBetType()].models[i].scale)
                    break
                end
            end
        end)

        self:NetworkVarNotify("Dealer", function(ent, name, old, new)
            if IsValid(self.dealer) then
                self.dealer:SetLocalPos(Vector(0, 30, 38.5))
                self.dealer:SetLocalAngles(Angle(0, 180, 0))
            end
        end)
    end

    if SERVER then
        self:NetworkVarNotify("Bots", function(ent,name,old,new)
            self:updateBots(self.botsInfo)
        end)

        self:NetworkVarNotify("Turn", function(ent, name, old, new)
            if self:GetGameState() > 0 and new != 0 then
                local state = gBlackjack.gameType[self:GetGameType()].states[self:GetGameState()]
                if state and state.blackjackAction then
                    self:promptBlackjackPlayer(new)
                end
            end
        end)
    end
end

function ENT:getDeckValue(deck)
    return gBlackjack.blackjackHandValue(deck)
end



