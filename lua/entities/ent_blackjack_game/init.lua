//Adding files

include("shared.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

//Blackjack info
ENT.deck = {}
ENT.decks = {}

//Functions//

function ENT:SpawnFunction(ply, tr, class)
    if !IsValid(ply) then return end

    net.Start("gblackjack_derma_createGame")
    net.Send(ply)
end

function ENT:Initialize()
    self:SetModel("models/props/de_tides/restaurant_table.mdl")
    self:SetModelScale(1.2, 0.00001)
    self:SetUseType(SIMPLE_USE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysWake()

    self.players = {}
    self.decks = {}
    self.deck = {}
    self.communityDeck = {}
    self.botsInfo = self.botsInfo or {}

    self:SetCheck(true)
    self:SetGameState(-1)
    self:SetDealer(1)
    self:SetPot(0)
    self:SetBet(0)
    self:SetTurn(0)
    self:SetWinner(0)
    self:SetGameType(0)
    self:SetDealerHitSoft17(false)
    self:SetAllowDouble(true)
    self:SetBlackjackPayout(0)
    self:SetDealerMessage("Welcome to the table.")

    util.PrecacheModel("models/cards/stack.mdl")
    util.PrecacheModel("models/cards/chip.mdl")
end

function ENT:setupBlackjackState(tab)
    tab.ready = true
    tab.fold = false
    tab.strength = nil
    tab.value = nil
    tab.paidBet = 0
    tab.wager = 0
    tab.stood = false
    tab.busted = false
    tab.blackjack = false
    tab.doubled = false
    tab.outcome = nil
    tab.handValue = 0
    tab.thinking = false
end

local dealerLines = {
    wager = {"Place your wagers.", "Cards are waiting. Wagers in.", "Minimum is posted. Choose your stake."},
    botWager = {"{style} sits in for {wager}.", "{style} likes {wager} here.", "{style} joins the hand at {wager}."},
    deal = {"Cards are out.", "Good luck. Cards are moving.", "Fresh hand. Watch the corners."},
    blackjack = {"Natural blackjack on the table.", "That is a clean blackjack.", "Twenty-one in two. Nicely done."},
    hit = {"Hit.", "Another card.", "Card coming."},
    double = {"Double down.", "One card only. Double is live.", "Bold move. Double down."},
    stand = {"Stand on {value}.", "Holding at {value}.", "Stays with {value}."},
    reveal = {"Dealer reveals the hole card.", "Dealer turns the card.", "House card is up."},
    dealerHit = {"Dealer hits {soft}{value}.", "House draws on {soft}{value}.", "Dealer needs one at {soft}{value}."},
    dealerStand = {"Dealer stands on {value}.", "House stays at {value}.", "Dealer locks in {value}."},
    settle = {"Bets settled. Next hand soon.", "Payouts are clean. Next hand shortly.", "That hand is closed. Shuffle up."}
}

function ENT:dealerSay(kind, data)
    local lines = dealerLines[kind]
    local line = lines and table.Random(lines) or kind

    for key, value in pairs(data or {}) do
        line = line:gsub("{" .. key .. "}", function() return tostring(value) end)
    end

    self:SetDealerMessage(line)
end
function ENT:updateBots(tab)
    tab = tab or {}
    local botNumNew = #tab
    local botNum = self:getBotsAmount()
    local addAmount = botNumNew - botNum

    if addAmount > 0 then
        for i = 1, addAmount do
            self:addBot(tab[botNum + i])
        end
    elseif addAmount < 0 then
        local removeAmount = math.abs(addAmount)
        local removed = 0

        for i = #self.players, 1, -1 do
            if self.players[i].bot then
                removed = removed + 1
                self:removeBot(Entity(self.players[i].ind))
                if removed >= removeAmount then break end
            end
        end
    end

    timer.Simple(0.1, function()
        if IsValid(self) then
            self:updatePlayersTable()
            if #self.players > 0 and self:GetGameState() == -1 then self:SetGameState(0) end
        end
    end)
end

function ENT:addBot(data)
    data = data or {}
    local index = #self.players + 1
    if index > self:GetMaxPlayers() then return end

    local seat = self:createSeat()
    seat:SetLocalPos(Vector(0,0,0))
    seat:SetLocalAngles(Angle(0,0,0))
    seat:Spawn()

    local bot = ents.Create("ent_blackjack_bot")
    bot:SetParent(seat)
    bot:SetLocalPos(Vector(0,0,20))
    bot:SetLocalAngles(Angle(0,90,0))
    bot:Spawn()
    bot:Activate()
    local style = data.aiStyle or math.random(1, #gBlackjack.botStyles)
    local styleInfo = gBlackjack.botStyles[style] or gBlackjack.botStyles[2]
    local botName = data.name or table.Random(gBlackjack.bots.names)
    bot:SetBotName(botName .. " [" .. styleInfo.name .. "]")
    bot:SetModel(data.mdl or "models/player/kleiner.mdl")
    bot:SetModelColor(data.clr or Vector(math.random(), math.random(), math.random()))
    bot:SetSequence("Sit")
    bot:SetFlexWeight(0, 0)
    seat:PhysicsInit(SOLID_NONE)
    seat:SetMoveType(MOVETYPE_NONE)
    seat:SetSolid(SOLID_NONE)

    self.players[index] = {bot = true, ind = bot:EntIndex(), aiStyle = style, aiStyleName = styleInfo.name}
    self:setupBlackjackState(self.players[index])
    self.decks[index] = {}

    gBlackjack.betType[self:GetBetType()].call(self, bot)

    self:updatePlayersTable()
    self:updateSeatsPositioning()
end

function ENT:updatePlayersTable()
    net.Start("gblackjack_updatePlayers")
        net.WriteEntity(self)
        net.WriteTable(self.players)
    net.Broadcast()
end

function ENT:Use(act)
    if self:GetGameState() < 1 then
        if !gBlackjack.getTableFromPlayer(act) and ((self:GetBotsPlaceholder() and self:getPlayersAmount() < self:GetMaxPlayers()) or (#self.players < self:GetMaxPlayers())) then
            timer.Simple(0.05, function()
                if !IsValid(self) or !IsValid(act) then return end

                if self:GetBotsPlaceholder() and #self.players >= self:GetMaxPlayers() then
                    for i = #self.players, 1, -1 do
                        if self.players[i].bot then self:removePlayerFromMatch(Entity(self.players[i].ind)) break end
                    end
                end

                local index = #self.players + 1
                self.players[index] = {ind = act:EntIndex()}
                self:setupBlackjackState(self.players[index])

                gBlackjack.betType[self:GetBetType()].call(self, act)
                self.decks[index] = {}

                self:updatePlayersTable()
                sound.Play("garrysmod/balloon_pop_cute.wav", self:GetPos())

                local seat = self:createSeat()
                seat:SetLocalPos(Vector(0,0,0))
                seat:SetLocalAngles(Angle(0,0,0))
                seat:Spawn()

                act:EnterVehicle(seat)
                act:SetEyeAngles(Angle(0,90,0))

                self:updateSeatsPositioning()

                if self:getPlayersAmount() > 0 and self:GetGameState() == -1 then self:SetGameState(0) end
            end)
        end
    end
end

function ENT:createSeat()
    local vehicleList = list.Get("Vehicles")
    local vehicle = vehicleList["Chair_Office2"]

    local seat = ents.Create(vehicle.Class)
    seat:SetModel(vehicle.Model)

    if (vehicle && vehicle.KeyValues) then
        for k, v in pairs(vehicle.KeyValues) do
            local kLower = string.lower(k)
            if (kLower == "vehiclescript" or kLower == "limitview" or kLower == "vehiclelocked" or kLower == "cargovisible" or kLower == "enablegun") then
                seat:SetKeyValue(k, v)
            end
        end
    end

    seat:SetVehicleClass("Chair_Office2")
    seat.VehicleName = "Chair_Office2"
    seat.VehicleTable = vehicle
    seat:SetMoveType(MOVETYPE_NONE)
    seat:SetCollisionGroup(COLLISION_GROUP_WORLD)
    seat:SetParent(self)

    return seat
end

function ENT:updateSeatsPositioning()
    local startAng = 90
    local startAngPos = 0
    local radius = 50
    for i = 1, #self.players do
        local ang = startAngPos - (360 / #self.players) * (i - 1)
        local ent = Entity(self.players[i].ind)
        if !IsValid(ent) then continue end

        local veh
        if self.players[i].bot then veh = ent:GetParent() else veh = ent:GetVehicle() end
        if !IsValid(veh) then continue end

        ang = math.rad(ang)
        local x = math.cos(ang) * radius
        local y = math.sin(ang) * radius

        veh:SetLocalPos(Vector(x, y, 0))
        veh:SetLocalAngles(Angle(0,startAng - (360 / #self.players) * (i - 1),0))
    end
end

function ENT:beginWagerRound()
    self:SetPot(0)
    self:SetBet(0)
    self:dealerSay("wager")
    self:SetWinner(0)
    self:SetTurn(0)
    self.communityDeck = {}

    local broke = {}
    for k,v in pairs(self.players) do
        self:setupBlackjackState(v)
        self.decks[k] = {}
        v.thinking = false

        local ent = Entity(v.ind)
        local available = gBlackjack.betType[self:GetBetType()].get(ent)
        if !IsValid(ent) or available < self:GetEntryBet() then
            broke[#broke + 1] = ent
        end
    end

    for k,v in pairs(broke) do
        if IsValid(v) then self:removePlayerFromMatch(v) end
    end

    if #self.players < 1 then
        self:prepareForRestart()
        return
    end

    for k,v in pairs(self.players) do
        v.ready = false
        local ent = Entity(v.ind)
        if v.bot then
            self:simulateBotWager(k)
        elseif IsValid(ent) then
            net.Start("gblackjack_derma_blackjackWager", false)
                net.WriteEntity(self)
                net.WriteFloat(self:GetEntryBet())
                net.WriteFloat(gBlackjack.betType[self:GetBetType()].get(ent))
            net.Send(ent)
        end
    end

    self:updatePlayersTable()
end

function ENT:simulateBotWager(key)
    timer.Simple(math.random(5, 15) * 0.1, function()
        if !IsValid(self) or self:GetGameState() != 1 or !self.players[key] then return end

        local ent = Entity(self.players[key].ind)
        local bankroll = gBlackjack.betType[self:GetBetType()].get(ent)
        local min = self:GetEntryBet()
        local style = self.players[key].aiStyle or 2
        local fraction = (gBlackjack.botStyles[style] and gBlackjack.botStyles[style].wager) or 0.2
        local max = math.max(min, math.floor(bankroll * fraction))
        local wager = math.Clamp(math.random(min, max), min, bankroll)

        self:placeBlackjackWager(key, wager)
    end)
end

function ENT:placeBlackjackWager(key, wager)
    local player = self.players[key]
    if !player or player.ready then return end

    local ent = Entity(player.ind)
    if !IsValid(ent) then return end

    local bankroll = gBlackjack.betType[self:GetBetType()].get(ent)
    wager = math.Clamp(math.floor(wager or 0), self:GetEntryBet(), bankroll)
    if wager < self:GetEntryBet() then
        self:removePlayerFromMatch(ent)
        return
    end

    gBlackjack.betType[self:GetBetType()].add(ent, -wager, self)
    player.wager = wager
    player.paidBet = wager
    if player.bot then self:dealerSay("botWager", {style = player.aiStyleName or "AI", wager = wager .. gBlackjack.betType[self:GetBetType()].fix}) end
    player.ready = true
    self:SetBet(wager)

    sound.Play("mvm/mvm_money_pickup.wav", self:GetPos())
    self:updatePlayersTable()

    if self:allPlayersReady() then self:nextState() end
end

function ENT:allPlayersReady()
    for k,v in pairs(self.players) do
        if !v.ready then return false end
    end

    return true
end

function ENT:beginRound()
    self:preGenerateDeck()
    self.communityDeck = {}
    self:dealerSay("deal")
    self:SetDealer(1)

    local delay = 0
    for round = 1, 2 do
        for i = 1, #self.players do
            local key = i
            timer.Simple(delay, function()
                if !IsValid(self) or self:GetGameState() < 1 or !self.players[key] then return end
                self:dealSingularCard(key)
                self:updateDecksPositioning(key)
                self:updatePlayersTable()
                sound.Play("gblackjack/cardthrow.wav", self:GetPos())
            end)
            delay = delay + 0.35
        end

        timer.Simple(delay, function()
            if !IsValid(self) or self:GetGameState() < 1 then return end
            local reveal = #self.communityDeck == 0
            self:dealDealerCard(reveal)
            sound.Play("gblackjack/cardthrow.wav", self:GetPos())
        end)
        delay = delay + 0.35
    end

    timer.Create("gblackjack_finishDealingCards" .. self:EntIndex(), delay + 0.35, 1, function()
        if !IsValid(self) then return end

        for k,v in pairs(self.players) do
            self:updateBlackjackState(k)
            if v.blackjack then
                v.stood = true
                v.ready = true
                self:dealerSay("blackjack")
            end
        end

        sound.Play("garrysmod/content_downloaded.wav", self:GetPos())
        self:updatePlayersTable()
        self:nextState()
    end)
end

function ENT:nextState()
    self:SetGameState(self:GetGameState() + 1)
    local state = gBlackjack.gameType[self:GetGameType()].states[self:GetGameState()]
    if state and state.func then state.func(self) end
end

function ENT:preGenerateDeck()
    self.deck = {}
    for i = 0, 3 do
        self.deck[i] = {}
        for r = 0, 12 do self.deck[i][r] = true end
    end
end

function ENT:dealSingularCard(p, key)
    if self:GetGameState() < 1 then return end

    local communityCard = p == nil
    local card

    if key == nil then
        card = ents.Create("ent_blackjack_card")
        card:SetParent(self)
        if !communityCard then card:SetOwner(Entity(self.players[p].ind)) else card:SetOwner(self) end
        card:Spawn()
        card:Activate()

        if !communityCard then
            key = #self.decks[p] + 1
            self.decks[p][key] = {ind = card:EntIndex()}
        else
            key = #self.communityDeck + 1
            self.communityDeck[key] = {ind = card:EntIndex(), reveal = false}
        end
    else
        if !communityCard then card = Entity(self.decks[p][key].ind) else card = Entity(self.communityDeck[key].ind) end
    end

    local tab
    if !communityCard then tab = self.decks[p][key] else tab = self.communityDeck[key] end

    local suit, rank
    repeat
        suit = math.random(0,3)
        rank = math.random(0,12)

        if self.deck[suit][rank] then
            tab.suit = suit
            tab.rank = rank
        end
    until self.deck[suit][rank]

    self.deck[suit][rank] = false

    if !communityCard then
        if IsValid(card) then
            card:SetRank(tab.rank)
            card:SetSuit(tab.suit)
        end

        local ply = Entity(self.players[p].ind)
        if IsValid(ply) and ply:IsPlayer() then
            net.Start("gblackjack_sendDeck")
                net.WriteEntity(self)
                net.WriteBool(false)
                net.WriteTable(self.decks[p])
            net.Send(ply)
        end
    end

    return key
end

function ENT:dealDealerCard(reveal)
    local key = self:dealSingularCard(nil)
    self.communityDeck[key].reveal = reveal
    if reveal then self:showDealerCard(key) end
    self:updateDecksPositioning(0)
    self:sendDealerDeck()
end

function ENT:showDealerCard(key)
    local data = self.communityDeck[key]
    if !data then return end

    data.reveal = true
    local card = Entity(data.ind)
    if IsValid(card) then
        card:SetRank(data.rank)
        card:SetSuit(data.suit)
    end
end

function ENT:sendDealerDeck()
    local clientCopy = {}
    for k,v in pairs(self.communityDeck) do
        clientCopy[k] = {reveal = v.reveal}
        if v.reveal then
            clientCopy[k].suit = v.suit
            clientCopy[k].rank = v.rank
        end
    end

    for k,v in pairs(self.players) do
        if !v.bot then
            local ply = Entity(v.ind)
            if IsValid(ply) then
                net.Start("gblackjack_sendDeck", false)
                    net.WriteEntity(self)
                    net.WriteBool(true)
                    net.WriteTable(clientCopy)
                net.Send(ply)
            end
        end
    end
end

function ENT:updateDecksPositioning(key)
    key = key or nil
    local startAngPos = 0
    local radius = 30

    if key != 0 then
        for i = 1, #self.players do
            if (key != nil and i == key) or (key == nil) then
                local ang = math.rad(startAngPos - (360 / #self.players) * (i - 1))
                local deckCenter = Vector(math.cos(ang) * radius, math.sin(ang) * radius, 39)

                for k,v in pairs(self.decks[i] or {}) do
                    local cardAng = (startAngPos - 180 - (360 / #self.players) * (i - 1)) + -15 * (k - math.Round(#self.decks[i] / 2))
                    local angle = Angle(0, cardAng, 0)
                    local rad = math.rad(cardAng)
                    local position = Vector(math.cos(rad) * 5 + deckCenter.x, math.sin(rad) * 5 + deckCenter.y, deckCenter.z + 0.05 * (k - 1))

                    if v.ind and IsValid(Entity(v.ind)) then
                        local card = Entity(v.ind)
                        card:SetLocalPos(position)
                        card:SetLocalAngles(angle)
                    end
                end
            end
        end
    else
        local count = #self.communityDeck
        for k,v in pairs(self.communityDeck) do
            local card = Entity(v.ind)
            if IsValid(card) then
                local x = (k - (count + 1) / 2) * 10
                card:SetLocalPos(Vector(x, 0, 39 + 0.05 * k))
                card:SetLocalAngles(v.reveal and Angle(0, 180, 0) or Angle(0, 180, 180))
            end
        end
    end
end

function ENT:updateBlackjackState(key)
    local player = self.players[key]
    if !player then return end

    local total = gBlackjack.blackjackHandValue(self.decks[key] or {})
    player.handValue = total
    player.blackjack = gBlackjack.blackjackIsNatural(self.decks[key] or {})
    player.busted = total > 21
end

function ENT:playerNeedsAction(key)
    local player = self.players[key]
    if !player then return false end
    if (player.wager or 0) <= 0 then return false end
    if player.stood or player.busted or player.blackjack then return false end
    return true
end

function ENT:playerActionRound()
    self:SetTurn(0)

    for k,v in pairs(self.players) do
        self:updateBlackjackState(k)
        v.ready = !self:playerNeedsAction(k)
    end

    self:updatePlayersTable()
    self:nextBlackjackTurn()
end

function ENT:nextBlackjackTurn()
    if #self.players < 1 then self:nextState() return end

    local start = self:GetTurn()
    for offset = 1, #self.players do
        local key = start + offset
        if key > #self.players then key = key - #self.players end

        if self:playerNeedsAction(key) then
            self:SetTurn(key)
            return
        end
    end

    self:SetTurn(0)
    self:nextState()
end

function ENT:promptBlackjackPlayer(key)
    local player = self.players[key]
    if !player or !self:playerNeedsAction(key) then
        self:nextBlackjackTurn()
        return
    end

    if player.bot then
        self:simulateBotAction(key)
        return
    end

    local ply = Entity(player.ind)
    if !IsValid(ply) then self:nextBlackjackTurn() return end

    local canDouble = self:GetAllowDouble() and #self.decks[key] == 2 and !player.doubled and gBlackjack.betType[self:GetBetType()].get(ply) >= player.wager

    net.Start("gblackjack_derma_blackjackAction", false)
        net.WriteEntity(self)
        net.WriteBool(canDouble)
    net.Send(ply)
end

function ENT:applyBlackjackAction(key, action)
    local player = self.players[key]
    if !player or !self:playerNeedsAction(key) then return end

    local ent = Entity(player.ind)
    if !IsValid(ent) then self:nextBlackjackTurn() return end

    if action == 0 then
        self:dealerSay("hit")
        self:dealSingularCard(key)
        self:updateDecksPositioning(key)
        sound.Play("gblackjack/cardthrow.wav", self:GetPos())
    elseif action == 2 then
        local bankroll = gBlackjack.betType[self:GetBetType()].get(ent)
        if self:GetAllowDouble() and #self.decks[key] == 2 and !player.doubled and bankroll >= player.wager then
            gBlackjack.betType[self:GetBetType()].add(ent, -player.wager, self)
            player.wager = player.wager * 2
            player.paidBet = player.wager
            player.doubled = true
            self:dealerSay("double")
            self:dealSingularCard(key)
            self:updateDecksPositioning(key)
            sound.Play("mvm/mvm_money_pickup.wav", self:GetPos())
            sound.Play("gblackjack/cardthrow.wav", self:GetPos())
        end
        player.stood = true
        player.ready = true
    else
        player.stood = true
        player.ready = true
        self:dealerSay("stand", {value = player.handValue or ""})
        sound.Play("gblackjack/check.wav", self:GetPos())
    end

    self:updateBlackjackState(key)
    if player.busted or player.handValue == 21 then
        player.stood = true
        player.ready = true
    end

    self:updatePlayersTable()

    timer.Simple(0.75, function()
        if !IsValid(self) or self:GetGameState() != 3 then return end
        if self:playerNeedsAction(key) then
            self:promptBlackjackPlayer(key)
        else
            self:nextBlackjackTurn()
        end
    end)
end

function ENT:getDealerUpValue()
    for k,v in pairs(self.communityDeck or {}) do
        if v.reveal then
            local value = gBlackjack.blackjackCardValue(v)
            return math.Clamp(value, 2, 11)
        end
    end

    return 10
end

function ENT:chooseBotAction(key)
    local player = self.players[key]
    local value, soft = gBlackjack.blackjackHandValue(self.decks[key] or {})
    local dealer = self:getDealerUpValue()
    local ent = Entity(player.ind)
    local canDouble = self:GetAllowDouble() and #self.decks[key] == 2 and !player.doubled and gBlackjack.betType[self:GetBetType()].get(ent) >= player.wager

    if canDouble then
        if player.aiStyle == 4 and value >= 9 and value <= 11 then return 2 end
        if player.aiStyle == 3 and !soft and value >= 9 and value <= 11 then return 2 end
        if !soft and (value == 11 or (value == 10 and dealer <= 9) or (value == 9 and dealer >= 3 and dealer <= 6)) then return 2 end
        if soft and ((value == 18 and dealer >= 3 and dealer <= 6) or (value >= 15 and value <= 17 and dealer >= 4 and dealer <= 6)) then return 2 end
    end

    if soft then
        if value >= 19 then return 1 end
        if value == 18 and dealer <= 8 then return 1 end
        return 0
    end

    if value >= 17 then return 1 end
    if player.aiStyle == 4 and value >= 12 and value <= 17 and math.random(1, 5) == 1 then return math.random(0, 1) end
    if player.aiStyle == 1 and value >= 16 then return 1 end
    if player.aiStyle == 3 and value <= 15 then return 0 end
    if value >= 13 and dealer <= 6 then return 1 end
    if value == 12 and dealer >= 4 and dealer <= 6 then return 1 end

    return 0
end

function ENT:simulateBotAction(key)
    timer.Simple(math.random(7, 18) * 0.1, function()
        if !IsValid(self) or self:GetGameState() != 3 or !self.players[key] then return end
        self.players[key].thinking = true
        self:updatePlayersTable()

        timer.Simple(math.random(5, 10) * 0.1, function()
            if !IsValid(self) or self:GetGameState() != 3 or !self.players[key] then return end
            self.players[key].thinking = false
            self:applyBlackjackAction(key, self:chooseBotAction(key))
        end)
    end)
end

function ENT:dealerRound()
    self:dealerSay("reveal")
    for k,v in pairs(self.communityDeck) do self:showDealerCard(k) end
    self:sendDealerDeck()
    self:updateDecksPositioning(0)

    local anyLive = false
    for k,v in pairs(self.players) do
        if (v.wager or 0) > 0 and !v.busted then anyLive = true break end
    end

    local function playDealer()
        if !IsValid(self) or self:GetGameState() != 4 then return end

        local value, soft = gBlackjack.blackjackHandValue(self.communityDeck)
        if anyLive and (value < 17 or (value == 17 and soft and self:GetDealerHitSoft17())) then
            self:dealerSay("dealerHit", {soft = soft and "soft " or "", value = value})
            self:dealDealerCard(true)
            timer.Simple(1.15, playDealer)
        else
            self:dealerSay("dealerStand", {value = value})
            self:updatePlayersTable()
            timer.Simple(1.6, function()
                if IsValid(self) and self:GetGameState() == 4 then self:nextState() end
            end)
        end
    end

    timer.Simple(1.1, playDealer)
end

function ENT:settleRound()
    self:SetTurn(0)
    local dealerValue = gBlackjack.blackjackHandValue(self.communityDeck)
    local dealerBust = dealerValue > 21
    local dealerBlackjack = gBlackjack.blackjackIsNatural(self.communityDeck)

    for key, player in pairs(self.players) do
        local ent = Entity(player.ind)
        local payout = 0

        self:updateBlackjackState(key)

        if (player.wager or 0) <= 0 then
            player.outcome = nil
        elseif player.busted then
            player.outcome = "lose"
        elseif dealerBlackjack then
            if player.blackjack then
                player.outcome = "push"
                payout = player.wager
            else
                player.outcome = "lose"
            end
        elseif player.blackjack then
            player.outcome = "blackjack"
            local payoutInfo = gBlackjack.blackjackPayouts[self:GetBlackjackPayout()] or gBlackjack.blackjackPayouts[0]
            payout = math.floor(player.wager * payoutInfo.multiplier)
        elseif dealerBust or player.handValue > dealerValue then
            player.outcome = "win"
            payout = player.wager * 2
        elseif player.handValue == dealerValue then
            player.outcome = "push"
            payout = player.wager
        else
            player.outcome = "lose"
        end

        if payout > 0 and IsValid(ent) then
            gBlackjack.betType[self:GetBetType()].add(ent, payout, self)
        end
    end

    self:SetPot(0)
    self:dealerSay("settle")
    self:updatePlayersTable()
    sound.Play("garrysmod/content_downloaded.wav", self:GetPos())

    timer.Simple(6, function()
        if !IsValid(self) then return end
        self:removePlayersBelowMinimum()
        self:prepareForRestart()
    end)
end

function ENT:removePlayersBelowMinimum()
    local remove = {}
    for k,v in pairs(self.players) do
        local ent = Entity(v.ind)
        if IsValid(ent) and gBlackjack.betType[self:GetBetType()].get(ent) < self:GetEntryBet() then
            remove[#remove + 1] = ent
        end
    end

    for k,v in pairs(remove) do
        if IsValid(v) then self:removePlayerFromMatch(v) end
    end
end

function ENT:removePlayerFromMatch(ply)
    if !IsValid(ply) then return end
    if !ply:IsPlayer() then self:removeBot(ply) return end

    local key = self:getPlayerKey(ply)
    if key == nil then return end

    local chair = ply:GetVehicle()
    ply:ExitVehicle()
    if IsValid(chair) then chair:Remove() end

    for k,v in pairs(self.decks[key] or {}) do
        if IsValid(Entity(v.ind)) then Entity(v.ind):Remove() end
    end

    table.remove(self.players, key)
    table.remove(self.decks, key)

    self:updateSeatsPositioning()
    self:updateDecksPositioning()
    self:updatePlayersTable()

    if self:getPlayersAmount() < 1 then
        self:prepareForRestart()
    elseif self:GetGameState() == 1 and self:allPlayersReady() then
        self:nextState()
    elseif self:GetGameState() == 3 and self:GetTurn() == key then
        self:SetTurn(0)
        self:nextBlackjackTurn()
    end
end

function ENT:removeBot(bot)
    if !IsValid(bot) then return end
    local key = self:getPlayerKey(bot)
    if key == nil then return end

    if self:GetTurn() == key and #self.players > 0 then self:SetTurn(0) end

    for k,v in pairs(self.decks[key] or {}) do
        if IsValid(Entity(v.ind)) then Entity(v.ind):Remove() end
    end

    table.remove(self.decks, key)
    table.remove(self.players, key)

    self:updateSeatsPositioning()
    self:updateDecksPositioning()
    self:updatePlayersTable()

    local parent = bot:GetParent()
    if IsValid(parent) then parent:Remove() end
    bot:Remove()
end

function ENT:prepareForRestart()
    if timer.Exists("gblackjack_intermission" .. self:EntIndex()) then timer.Remove("gblackjack_intermission" .. self:EntIndex()) end
    if timer.Exists("gblackjack_finishDealingCards" .. self:EntIndex()) then timer.Remove("gblackjack_finishDealingCards" .. self:EntIndex()) end
    if timer.Exists("gblackjack_dealCards" .. self:EntIndex()) then timer.Remove("gblackjack_dealCards" .. self:EntIndex()) end

    self:SetWinner(0)
    self:SetTurn(0)
    self:SetBet(0)
    self:SetPot(0)
    self:SetCheck(true)

    for k,v in pairs(self.players) do
        self:setupBlackjackState(v)
        self.decks[k] = {}
        v.thinking = false
    end

    self.deck = {}
    self.communityDeck = {}

    local cards = ents.FindByClassAndParent("ent_blackjack_card", self)
    if cards then
        for k,v in pairs(cards) do v:Remove() end
    end

    self:updatePlayersTable()

    if #self.players > 0 then
        self:SetGameState(0)
    else
        self:SetGameState(-1)
        self:updateBots(self.botsInfo)
        for k,v in pairs(self.players) do
            gBlackjack.betType[self:GetBetType()].call(self, Entity(v.ind))
        end
    end
end







