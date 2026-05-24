gBlackjack = gBlackjack or {}

gBlackjack.model = Model("")

// Blackjack game. Internal gblackjack names are kept so old assets and entities still resolve.
gBlackjack.gameType = {
    [0] = {
        name        = "Blackjack",
        cardNum     = 2,
        cardDraw    = false,
        cardComm    = true,
        cardCommNum = 0,
        cardCanSee  = true,
        available   = true,
        states      = {
            [1] = {
                text = "Place Wagers",
                func = function(e) if CLIENT then return end e:beginWagerRound() end
            },
            [2] = {
                text = "Dealing Cards...",
                func = function(e) if CLIENT then return end e:beginRound() end
            },
            [3] = {
                text = function(e)
                    if !IsValid(e) then return "Players Acting" end
                    local turn = e:GetTurn()
                    if turn > 0 and e.players[turn] then
                        local ent = Entity(e.players[turn].ind)
                        if IsValid(ent) then
                            if ent:IsPlayer() then return ent:Nick() .. " to act" end
                            return ent:GetBotName() .. " to act"
                        end
                    end
                    return "Players Acting"
                end,
                func = function(e) if CLIENT then return end e:playerActionRound() end,
                blackjackAction = true
            },
            [4] = {
                text = "Dealer Plays",
                func = function(e) if CLIENT then return end e:dealerRound() end
            },
            [5] = {
                text = "Settling Bets",
                func = function(e) if CLIENT then return end e:settleRound() end,
                final = true
            }
        }
    }
}


function gBlackjack.nMoney2Available()
    if nMoneyServerSettings != nil then return true end
    if scripted_ents and (scripted_ents.GetStored("ent_atm") or scripted_ents.GetStored("ent_money")) then return true end
    if CLIENT and IsValid(LocalPlayer()) then return LocalPlayer():GetNWString("WalletMoney", "") != "" end
    return false
end

function gBlackjack.nMoney2SteamId(ply)
    if !IsValid(ply) then return nil end
    return string.Replace(ply:SteamID(), ":", "")
end

function gBlackjack.nMoney2Wallet(ply)
    if !IsValid(ply) then return 0 end
    return tonumber(ply:GetNWString("WalletMoney", "0")) or 0
end

function gBlackjack.nMoney2SetWallet(ply, amount)
    if CLIENT then return end
    if !IsValid(ply) then return end

    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if nMoneyServerSettings and nMoneyServerSettings.MAX_WALLET_MONEY then
        amount = math.min(amount, tonumber(nMoneyServerSettings.MAX_WALLET_MONEY) or amount)
    end

    ply:SetNWString("WalletMoney", tostring(amount))

    local steamId = gBlackjack.nMoney2SteamId(ply)
    if steamId then
        file.CreateDir("nmoney2/wallet")
        file.Write("nmoney2/wallet/" .. steamId .. ".txt", ply:GetNWString("WalletMoney"))
    end
end
// Blackjack wagers.
gBlackjack.betType = {
    [0] = {
        name        = "Money",
        fix         = "$",
        canSet      = engine.ActiveGamemode() != "darkrp",
        setMinMax   = {min = 0, max = 10000},
        feeMinMax   = {min = 1, max = function(setSlider)
            if CLIENT then
                if engine.ActiveGamemode() != "darkrp" then
                    return math.max(1, setSlider:GetValue())
                else
                    return math.max(1, LocalPlayer():getDarkRPVar("money") or 0)
                end
            end
        end},
        get         = function(p)
            if !IsValid(p) then return 0 end

            local isDarkRp = engine.ActiveGamemode() == "darkrp"

            if !isDarkRp or (isDarkRp and !p:IsPlayer()) then
                local e = gBlackjack.getTableFromPlayer(p)
                if !IsValid(e) then return 0 end

                local key = e:getPlayerKey(p)
                if key == nil then return 0 end

                return e.players[key].money or 0
            else
                return p:getDarkRPVar("money") or 0
            end
        end,
        add         = function(p, a, e)
            if CLIENT then return end
            if !IsValid(p) then return end
            if !IsValid(e) then return end

            local isDarkRp = engine.ActiveGamemode() == "darkrp"
            a = a or 0

            if !isDarkRp or (isDarkRp and !p:IsPlayer()) then
                local key = e:getPlayerKey(p)
                if key == nil then return end

                e.players[key].money = (e.players[key].money or 0) + a
                e:updatePlayersTable()
            else
                p:addMoney(a)
            end

            e:SetPot(math.max(0, e:GetPot() - a))
        end,
        call = function(s, p)
            if !(engine.ActiveGamemode() == "darkrp") then
                s.players[s:getPlayerKey(p)].money = s:GetStartValue()
            elseif !p:IsPlayer() then
                s.players[s:getPlayerKey(p)].money = math.random(100,1000)
            end
        end,
        models      = {
            [1] = {mdl = Model("models/items/currencypack_small.mdl"), val = 100, scale = 0.5},
            [2] = {mdl = Model("models/items/currencypack_medium.mdl"), val = 1000, scale = 0.5},
            [3] = {mdl = Model("models/items/currencypack_large.mdl"), val = 999999, scale = 0.5}
        }
    },

    [1] = {
        name        = "Health",
        fix         = "HP",
        canSet      = false,
        setMinMax   = {min = 0, max = 0},
        feeMinMax   = {min = 1, max = function() if CLIENT then return math.max(1, LocalPlayer():GetMaxHealth()) end end},
        get         = function(p)
            if !IsValid(p) then return 0 end
            if p:IsPlayer() then
                return p:Health()
            else
                local ent = gBlackjack.getTableFromPlayer(p)
                if !IsValid(ent) then return 0 end

                local key = ent:getPlayerKey(p)
                if key == nil then return 0 end
                return ent.players[key].health or 0
            end
        end,
        add         = function(p, a, e)
            if CLIENT then return end
            if !IsValid(p) then return end
            if !IsValid(e) then return end

            a = a or 0
            local hp = gBlackjack.betType[e:GetBetType()].get(p) + a

            if hp < 1 then
                e:removePlayerFromMatch(p)
                if p:IsPlayer() then p:Kill() end
            else
                if p:IsPlayer() then
                    p:SetHealth(hp)
                else
                    e.players[e:getPlayerKey(p)].health = hp
                    e:updatePlayersTable()
                end
            end

            e:SetPot(math.max(0, e:GetPot() - a))
        end,
        call = function(s, p)
            if !p:IsPlayer() then
                s.players[s:getPlayerKey(p)].health = 100 + math.random(0,150)
            end
        end,
        models      = {
            [1] = {mdl = Model("models/healthvial.mdl"), val = 100, scale = 1},
            [2] = {mdl = Model("models/Items/HealthKit.mdl"), val = 999999, scale = 1}
        }
    },
    [2] = {
        name        = "nMoney2 Wallet",
        fix         = "$",
        canSet      = false,
        canUse      = function() return gBlackjack.nMoney2Available() end,
        setMinMax   = {min = 0, max = 0},
        feeMinMax   = {min = 1, max = function()
            if CLIENT then return math.max(1, gBlackjack.nMoney2Wallet(LocalPlayer())) end
        end},
        get         = function(p)
            if !IsValid(p) then return 0 end
            if p:IsPlayer() and gBlackjack.nMoney2Available() then
                return gBlackjack.nMoney2Wallet(p)
            end

            local ent = gBlackjack.getTableFromPlayer(p)
            if !IsValid(ent) then return 0 end
            local key = ent:getPlayerKey(p)
            if key == nil then return 0 end
            return ent.players[key].money or 0
        end,
        add         = function(p, a, e)
            if CLIENT then return end
            if !IsValid(p) or !IsValid(e) then return end

            a = a or 0
            if p:IsPlayer() and gBlackjack.nMoney2Available() then
                gBlackjack.nMoney2SetWallet(p, gBlackjack.nMoney2Wallet(p) + a)
            else
                local key = e:getPlayerKey(p)
                if key == nil then return end
                e.players[key].money = (e.players[key].money or 0) + a
                e:updatePlayersTable()
            end

            e:SetPot(math.max(0, e:GetPot() - a))
        end,
        call = function(s, p)
            if !p:IsPlayer() then
                s.players[s:getPlayerKey(p)].money = math.random(100, 1000)
            end
        end,
        models      = {
            [1] = {mdl = Model("models/items/currencypack_small.mdl"), val = 100, scale = 0.5},
            [2] = {mdl = Model("models/items/currencypack_medium.mdl"), val = 1000, scale = 0.5},
            [3] = {mdl = Model("models/items/currencypack_large.mdl"), val = 999999, scale = 0.5}
        }
    }
}

// Cards materials, for HUD.
gBlackjack.cards = {}
for s = 0, 3 do
    gBlackjack.cards[s] = {}
    for r = 0, 12 do
        gBlackjack.cards[s][r] = Material("gblackjack/cards/" .. s .. r .. ".png")
    end
end

gBlackjack.suit = {
    [0] = "Club",
    [1] = "Diamond",
    [2] = "Heart",
    [3] = "Spade"
}

gBlackjack.rank = {
    [0] = "Two",
    [1] = "Three",
    [2] = "Four",
    [3] = "Five",
    [4] = "Six",
    [5] = "Seven",
    [6] = "Eight",
    [7] = "Nine",
    [8] = "Ten",
    [9] = "Jack",
    [10] = "Queen",
    [11] = "King",
    [12] = "Ace"
}

gBlackjack.blackjackOutcome = {
    win = "Win",
    lose = "Lose",
    push = "Push",
    blackjack = "Blackjack"
}

gBlackjack.blackjackPayouts = {
    [0] = {name = "Blackjack pays 3:2", multiplier = 2.5},
    [1] = {name = "Blackjack pays 6:5", multiplier = 2.2},
    [2] = {name = "Blackjack pays 1:1", multiplier = 2}
}

gBlackjack.botStyles = {
    [1] = {name = "Cautious", wager = 0.12},
    [2] = {name = "Basic Strategy", wager = 0.2},
    [3] = {name = "High Roller", wager = 0.34},
    [4] = {name = "Wildcard", wager = 0.45}
}

// Bots section.
gBlackjack.bots = {}
gBlackjack.bots.names = {"Marlowe", "Velvet Jack", "The Accountant", "Ruby Seven", "Chip Mercer", "Ace Dalton", "Soft Seventeen", "The Regular", "Doubledown Dana", "Night Shift", "Pit Boss Paul", "Green Felt", "House Guest", "Risky Rina", "Quiet Quinn", "Stack Builder", "Sharp Suit", "Pocket Ace", "Lucky Charm", "Button Masher"}

function gBlackjack.getTableFromPlayer(p)
    if !IsValid(p) then return end

    local tables = ents.FindByClass("ent_blackjack_game")
    if !table.IsEmpty(tables) then
        for k,v in pairs(tables) do
            local key = v:getPlayerKey(p)
            if key != nil then return v end
        end
    end

    return nil
end

function gBlackjack.blackjackCardValue(card)
    if !card or card.rank == nil then return 0, false end
    if card.rank == 12 then return 11, true end
    if card.rank >= 8 then return 10, false end
    return card.rank + 2, false
end

function gBlackjack.blackjackHandValue(deck)
    local total = 0
    local softAces = 0

    for k,v in pairs(deck or {}) do
        local value, ace = gBlackjack.blackjackCardValue(v)
        total = total + value
        if ace then softAces = softAces + 1 end
    end

    while total > 21 and softAces > 0 do
        total = total - 10
        softAces = softAces - 1
    end

    return total, softAces > 0
end

function gBlackjack.blackjackIsNatural(deck)
    local total = gBlackjack.blackjackHandValue(deck)
    return #(deck or {}) == 2 and total == 21
end

function gBlackjack.blackjackHandText(deck)
    local total, soft = gBlackjack.blackjackHandValue(deck)
    if gBlackjack.blackjackIsNatural(deck) then return "Blackjack" end
    if total > 21 then return "Bust (" .. total .. ")" end
    if soft then return "Soft " .. total end
    return tostring(total)
end

function gBlackjack.fancyDeckStrength(st, vl)
    return tostring(st or "")
end


