util.AddNetworkString("gblackjack_derma_createGame")
util.AddNetworkString("gblackjack_updatePlayers")
util.AddNetworkString("gblackjack_sendDeck")
util.AddNetworkString("gblackjack_derma_leaveRequest")
util.AddNetworkString("gblackjack_derma_blackjackWager")
util.AddNetworkString("gblackjack_derma_blackjackAction")

net.Receive("gblackjack_derma_createGame", function(l, p)
    if !IsValid(p) then return end

    local tr = p:GetEyeTraceNoCursor()
    local pos = tr.HitPos + tr.HitNormal * 10
    local ang = p:EyeAngles()
    ang.p = 0
    ang.y = ang.y + 180

    local options = net.ReadTable()

    local blackjack = ents.Create("ent_blackjack_game")
    blackjack:SetPos(pos)
    blackjack:SetAngles(ang)
    blackjack.botsInfo = options.bot.list or {}
    blackjack:Spawn()
    blackjack:Activate()

    undo.Create("GBlackjack Table")
        undo.AddEntity(blackjack)
        undo.SetPlayer(p)
    undo.Finish()

    blackjack:SetGameType(0)
    blackjack:SetMaxPlayers(math.Clamp(options.game.maxPly or 4, 1, 8))

    local betTypeId = options.bet.type or 0
    local betType = gBlackjack.betType[betTypeId]
    if !betType or (betType.canUse and !betType.canUse()) then betTypeId = 0 end
    blackjack:SetBetType(betTypeId)
    blackjack:SetEntryBet(math.max(1, options.bet.entry or 1))
    blackjack:SetStartValue(math.max(0, options.bet.start or 0))

    local rules = options.rules or {}
    blackjack:SetDealerHitSoft17(rules.hitSoft17 or false)
    blackjack:SetAllowDouble(rules.allowDouble != false)
    blackjack:SetBlackjackPayout(rules.payout or 0)
    blackjack:SetDealerMessage("Welcome to the table.")

    blackjack:SetBotsPlaceholder(options.bot.placehold or false)
    blackjack:SetBots(#blackjack.botsInfo)
end)

net.Receive("gblackjack_derma_blackjackWager", function(_, ply)
    local ent = net.ReadEntity()
    local wager = math.floor(net.ReadFloat() or 0)

    if !IsValid(ent) then return end
    if ent:GetGameState() != 1 then return end

    local key = ent:getPlayerKey(ply)
    if key == nil then return end

    ent:placeBlackjackWager(key, wager)
end)

net.Receive("gblackjack_derma_blackjackAction", function(_, ply)
    local ent = net.ReadEntity()
    local action = net.ReadUInt(2)

    if !IsValid(ent) then return end
    if ent:GetGameState() != 3 then return end

    local key = ent:getPlayerKey(ply)
    if key == nil or ent:GetTurn() != key then return end

    ent:applyBlackjackAction(key, action)
end)

net.Receive("gblackjack_derma_leaveRequest", function(l, ply)
    local blackjack = net.ReadEntity()
    if IsValid(blackjack) then blackjack:removePlayerFromMatch(ply) end
end)

hook.Add("CanProperty", "gblackjack_blockSkinChange", function(ply, property, ent)
    if ent:GetClass() == "ent_blackjack_card" then return false end
end)

hook.Add("PlayerDisconnected", "gblackjack_playerDisconnected", function(ply)
    local ent = gBlackjack.getTableFromPlayer(ply)

    if IsValid(ent) then
        ent:removePlayerFromMatch(ply)
    end
end)

hook.Add("CanExitVehicle", "gblackjack_disableSeatExitting", function(veh, ply)
    if veh:GetVehicleClass() == "Chair_Office2" and IsValid(veh:GetParent()) and veh:GetParent():GetClass() == "ent_blackjack_game" then return false end
end)

hook.Add("EntityTakeDamage", "gblackjack_nullifyPlayerDamage", function(attacked, dmgInfo)
    local attacker = dmgInfo:GetAttacker()

    if (attacked:IsPlayer() and attacked:InVehicle() and IsValid(attacked:GetVehicle():GetParent()) and attacked:GetVehicle():GetParent():GetClass() == "ent_blackjack_game") or (attacker:IsPlayer() and attacker:InVehicle() and IsValid(attacker:GetVehicle():GetParent()) and attacker:GetVehicle():GetParent():GetClass() == "ent_blackjack_game") then
        dmgInfo:SetDamage(0)
    end
end)

hook.Add("CanPlayerSuicide", "gblackjack_disableKillBind", function(ply)
    if ply:InVehicle() and IsValid(ply:GetVehicle():GetParent()) and ply:GetVehicle():GetParent():GetClass() == "ent_blackjack_game" then
        return false
    end
end)

hook.Add("CanPlayerEnterVehicle", "gblackjack_disallowSittingOnBotSeats", function(ply, veh, role)
    if !table.IsEmpty(veh:GetChildren()) then
        for k,v in pairs(veh:GetChildren()) do
            if v:GetClass() == "ent_blackjack_bot" then return false end
        end
    end
end)


