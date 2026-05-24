include("shared.lua")

ENT.localDeck = {}
ENT.deckPot = NULL
ENT.dealer = NULL

local buttonOutline = 2
local feltDark = Color(13, 31, 22, 235)
local feltPanel = Color(18, 64, 43, 230)
local feltGreen = Color(20, 104, 62)
local feltHover = Color(28, 139, 82)
local feltGold = Color(205, 169, 82)
local mutedText = Color(230, 224, 202)

local function drawPanel(x, y, w, h)
    surface.SetDrawColor(feltDark)
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(feltGold)
    surface.DrawOutlinedRect(x, y, w, h, 2)
end

local function paintButton(self, w, h, enabled)
    enabled = enabled == nil or enabled
    if !enabled then
        surface.SetDrawColor(Color(24,38,30))
    elseif self:IsHovered() then
        surface.SetDrawColor(feltHover)
    else
        surface.SetDrawColor(feltGreen)
    end
    surface.DrawRect(0,0,w,h)
    surface.SetDrawColor(feltHover)
    surface.DrawOutlinedRect(0,0,w,h,buttonOutline)
end

local function drawHudCard(card, x, y, w, h)
    draw.RoundedBox(6, x - 2, y - 2, w, h, Color(0,0,0,127))

    if card and card.suit != nil and card.rank != nil then
        surface.SetDrawColor(255,255,255,255)
        surface.SetMaterial(gBlackjack.cards[card.suit][card.rank])
        surface.DrawTexturedRect(x, y, w, h)
    else
        draw.RoundedBox(6, x, y, w, h, Color(16, 58, 39, 255))
        surface.SetDrawColor(feltGold.r, feltGold.g, feltGold.b)
        surface.DrawOutlinedRect(x, y, w, h, 2)
        draw.SimpleText("?", "gblackjack_header", x + w / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function playerStatus(player)
    if !player then return "" end
    if player.outcome then return gBlackjack.blackjackOutcome[player.outcome] or player.outcome end
    if player.thinking then return "Thinking..." end
    if player.blackjack then return "Blackjack" end
    if player.busted then return "Bust" end
    if player.stood then return "Stand " .. (player.handValue or 0) end
    if (player.wager or 0) > 0 then return "Wager " .. player.wager end
    if player.aiStyleName then return player.aiStyleName end
    return "Waiting"
end

function ENT:Draw()
    self:DrawModel()

    if IsValid(self.deckPot) then
        if self:GetGameState() > -1 then
            local ang = EyeAngles()
            ang.p = 0
            ang.r = 0
            ang:RotateAroundAxis(ang:Up(), -90)
            ang:RotateAroundAxis(ang:Forward(), 90)

            local text = ""
            if self:GetGameState() == 0 and timer.Exists("gblackjack_intermission" .. self:EntIndex()) then
                text = math.floor(timer.TimeLeft("gblackjack_intermission" .. self:EntIndex())) + 1
            else
                text = self:GetPot() .. gBlackjack.betType[self:GetBetType()].fix
            end

            cam.Start3D2D(self.deckPot:GetPos() + self.deckPot:GetUp() * 15, ang, 0.2)
                draw.SimpleText(text, "gblackjack_header", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end

        self.deckPot:SetLocalAngles(Angle(0,CurTime() % 360 * 10,0))
        self.deckPot:SetLocalPos(Vector(0,0,math.sin(CurTime() * 3) + 39))
    end

    for k,v in pairs(self.players or {}) do
        local ent = Entity(v.ind)
        if IsValid(ent) and self:GetPos():Distance(LocalPlayer():GetPos()) <= 256 then
            local ang = EyeAngles()
            ang.p = 0
            ang.r = 0
            ang:RotateAroundAxis(ang:Up(), -90)
            ang:RotateAroundAxis(ang:Forward(), 90)

            local mult = 15
            if !ent:IsPlayer() then mult = 45 end
            local pos = ent:EyePos() + ent:GetUp() * mult

            cam.Start3D2D(pos, ang, 0.15)
                local nick
                if ent:IsPlayer() then nick = ent:Nick() else nick = "[BOT] " .. ent:GetBotName() end

                surface.SetFont("gblackjack_header")
                local fontW, fontH = surface.GetTextSize(nick)
                surface.SetFont("gblackjack_text")
                local state = playerStatus(v)
                local stateW, stateH = surface.GetTextSize(state)
                local bgW = math.Clamp(math.max(fontW, stateW), 85, 1000) + 10
                local bgH = fontH + stateH + 10

                local bgClr = feltDark
                local txtClr = mutedText
                local outClr = Color(feltGold.r, feltGold.g, feltGold.b, 255)
                if self:GetGameState() == 3 and self:GetTurn() != k then
                    bgClr = Color(13,31,22,145)
                    txtClr = Color(255,255,255,150)
                    outClr = Color(feltGold.r, feltGold.g, feltGold.b, 150)
                end

                surface.SetDrawColor(bgClr:Unpack())
                surface.DrawRect(-bgW/2, -bgH/2, bgW, bgH)
                surface.SetDrawColor(outClr:Unpack())
                surface.DrawOutlinedRect(-bgW/2, -bgH/2, bgW, bgH, 2)

                draw.SimpleText(nick, "gblackjack_header", 0, -bgH/2 + 5, txtClr, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                draw.SimpleText(state, "gblackjack_text", 0, -bgH/2 + 5 + fontH, txtClr, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            cam.End3D2D()
        end
    end
end

function ENT:Initialize()
    self.deckPot = ClientsideModel("models/cards/stack.mdl", RENDERGROUP_BOTH)
    self.deckPot:SetParent(self)
    self.deckPot:SetModelScale(1.75)
    self.deckPot:SetLocalPos(Vector(0,0,38.5))
    self.deckPot:SetLocalAngles(Angle(0,0,0))

    hook.Add("HUDPaint", "gblackjack_hudPaint" .. self:EntIndex(), function()
        if !IsValid(self) then return end

        if self:BeingLookedAtByLocalPlayer() and self:GetPos():Distance(LocalPlayer():GetPos()) < 128 and self:GetGameState() < 1 then
            if !self:getPlayerKey(LocalPlayer()) then
                surface.SetFont("gblackjack_bold")
                local plyHeader = "Players: "
                local startHeader = "Starting Value: "
                local entryHeader = "Minimum Wager: "
                local plyW = surface.GetTextSize(plyHeader)
                local startW = surface.GetTextSize(startHeader)
                local entryW = surface.GetTextSize(entryHeader)
                local x, y = ScrW() / 2, ScrH() / 2
                local bW, bH = 360, 155
                local pad = 8
                local _, fontH = surface.GetTextSize("W")

                drawPanel(x - bW / 2, y - bH / 2, bW, bH)
                draw.SimpleText("GBlackjack", "gblackjack_header", x, y - bH / 2 + pad, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                draw.SimpleText(plyHeader, "gblackjack_bold", x - bW / 2 + pad, y - bH / 2 + fontH + pad + 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("(" .. #self.players .. "/" .. self:GetMaxPlayers() .. ")", "gblackjack_text", x - bW / 2 + pad + plyW, y - bH / 2 + fontH + pad + 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(entryHeader, "gblackjack_bold", x - bW / 2 + pad, y - bH / 2 + fontH * 2 + pad + 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(self:GetEntryBet() .. gBlackjack.betType[self:GetBetType()].fix, "gblackjack_text", x - bW / 2 + pad + entryW, y - bH / 2 + fontH * 2 + pad + 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if gBlackjack.betType[self:GetBetType()].canSet then
                    draw.SimpleText(startHeader, "gblackjack_bold", x - bW / 2 + pad, y - bH / 2 + fontH * 3 + pad + 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(self:GetStartValue() .. gBlackjack.betType[self:GetBetType()].fix, "gblackjack_text", x - bW / 2 + pad + startW, y - bH / 2 + fontH * 3 + pad + 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local canJoin = true
                for k,v in pairs(ents.FindByClass("ent_blackjack_game")) do
                    if v:getPlayerKey(LocalPlayer()) then canJoin = false break end
                end

                local text = "Press [" .. string.upper(input.LookupBinding("+use") or "USE") .. "] to join."
                if !canJoin then text = "Cannot join - already in a match." end
                if #self.players >= self:GetMaxPlayers() and (!self:GetBotsPlaceholder()) then text = "Cannot join - match full" end
                draw.SimpleText(text, "gblackjack_bold", x, y + bH / 2 - pad, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end
        end

        local localKey = self:getPlayerKey(LocalPlayer())
        if self.players and self.players[localKey] then
            local cardW, cardH = 112, 168
            local bottomY = ScrH() - cardH - 24
            local center = ScrW() / 2

            if self:GetGameState() > 0 then
                if #self.localDeck > 0 then
                    for i = 1, #self.localDeck do
                        local x = center - ((#self.localDeck - 1) * 54) / 2 + (i - 1) * 54 - cardW / 2
                        drawHudCard(self.localDeck[i], x, bottomY, cardW, cardH)
                    end
                end

                if #self.communityDeck > 0 then
                    local dealerY = bottomY - cardH - 42
                    for i = 1, #self.communityDeck do
                        local x = center - ((#self.communityDeck - 1) * 54) / 2 + (i - 1) * 54 - cardW / 2
                        drawHudCard(self.communityDeck[i], x, dealerY, cardW, cardH)
                    end
                    draw.SimpleText("Dealer", "gblackjack_header", center, dealerY - 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                local sideW, sideH = 210, 148
                drawPanel(center + 250, ScrH() - sideH - 24, sideW, sideH)
                local player = self.players[localKey]
                local handText = gBlackjack.blackjackHandText(self.localDeck or {})
                draw.SimpleText(gBlackjack.betType[self:GetBetType()].get(LocalPlayer()) .. gBlackjack.betType[self:GetBetType()].fix, "gblackjack_header", center + 250 + sideW/2, ScrH() - sideH - 12, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                draw.SimpleText("Wager: " .. (player.wager or 0) .. gBlackjack.betType[self:GetBetType()].fix, "gblackjack_text", center + 264, ScrH() - sideH + 42, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("Table: " .. self:GetPot() .. gBlackjack.betType[self:GetBetType()].fix, "gblackjack_text", center + 264, ScrH() - sideH + 68, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("Hand: " .. handText, "gblackjack_text", center + 264, ScrH() - sideH + 94, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local upW, upH = 560, 82
            drawPanel(ScrW()/2 - upW/2, -2, upW, upH)

            local state
            if self:GetGameState() > 0 then
                local stateInfo = gBlackjack.gameType[self:GetGameType()].states[self:GetGameState()]
                if isfunction(stateInfo.text) then state = stateInfo.text(self) else state = stateInfo.text end
            elseif self:GetGameState() == 0 then
                state = "Intermission"
            else
                state = "Waiting for players"
            end

            local dealerMessage = self:GetDealerMessage()
            if dealerMessage and dealerMessage != "" then state = dealerMessage end
            draw.SimpleText("GBlackjack", "gblackjack_header", ScrW()/2, 22, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(state, "gblackjack_bold", ScrW()/2, 55, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)
end

function ENT:OnRemove()
    if IsValid(self.deckPot) then self.deckPot:Remove() end
    if IsValid(self.dealer) then self.dealer:Remove() end
    hook.Remove("HUDPaint", "gblackjack_hudPaint" .. self:EntIndex())
end

function ENT:openBlackjackWagerDerma(minWager, maxWager)
    local w, h = 430, 190
    maxWager = math.max(minWager, maxWager)

    local win = vgui.Create("DFrame")
    win:SetTitle("Place Wager")
    win:SetSize(w, h)
    win:Center()
    win:SetVisible(true)
    win:SetDraggable(false)
    win:ShowCloseButton(false)
    win.Paint = function(self, w, h)
        surface.SetDrawColor(feltDark)
        surface.DrawRect(0,20,w,h-20)
        surface.SetDrawColor(feltHover)
        surface.DrawRect(0,0,w,20)
        surface.DrawOutlinedRect(0,20,w,h-20,2)
    end
    win:SetPopupStayAtBack(true)
    win:MakePopup()

    local slider = vgui.Create("DNumSlider", win)
    slider:SetDecimals(0)
    slider:SetText("Wager")
    slider:SetDark(false)
    slider:SetPos(18, 44)
    slider:SetSize(w - 36, 42)
    slider:SetMinMax(minWager, maxWager)
    slider:SetValue(minWager)

    local wager = vgui.Create("DButton", win)
    wager:SetSize(w/2, 82)
    wager:SetPos(0, 108)
    wager:SetFont("gblackjack_header")
    wager:SetTextColor(color_white)
    wager:SetText("Wager")
    wager.Paint = function(self, bw, bh) paintButton(self, bw, bh, true) end
    wager.DoClick = function()
        net.Start("gblackjack_derma_blackjackWager", false)
            net.WriteEntity(self)
            net.WriteFloat(math.floor(slider:GetValue()))
        net.SendToServer()
        win:Close()
    end

    local leave = vgui.Create("DButton", win)
    leave:SetSize(w/2, 82)
    leave:SetPos(w/2, 108)
    leave:SetFont("gblackjack_header")
    leave:SetTextColor(color_white)
    leave:SetText("Leave")
    leave.Paint = function(self, bw, bh) paintButton(self, bw, bh, true) end
    leave.DoClick = function()
        net.Start("gblackjack_derma_leaveRequest")
            net.WriteEntity(self)
        net.SendToServer()
        win:Close()
    end
end

function ENT:openBlackjackActionDerma(canDouble)
    self.lastBlackjackCanDouble = canDouble
    local w, h = 480, 170
    local win = vgui.Create("DFrame")
    win:SetTitle("Blackjack")
    win:SetSize(w, h)
    win:Center()
    win:SetVisible(true)
    win:SetDraggable(false)
    win:ShowCloseButton(true)
    win.Close = function()
        self:openLeaveRequest()
        win:Remove()
    end
    win.Paint = function(self, w, h)
        surface.SetDrawColor(feltDark)
        surface.DrawRect(0,20,w,h-20)
        surface.SetDrawColor(feltHover)
        surface.DrawRect(0,0,w,20)
        surface.DrawOutlinedRect(0,20,w,h-20,2)
    end
    win:SetPopupStayAtBack(true)
    win:MakePopup()

    local labels = {"Hit", "Stand", "Double"}
    local actions = {0, 1, 2}
    for i = 1, 3 do
        local enabled = i != 3 or canDouble
        local btn = vgui.Create("DButton", win)
        btn:SetSize(w/3, h-20)
        btn:SetPos((i-1) * w/3, 20)
        btn:SetFont("gblackjack_header")
        btn:SetTextColor(enabled and color_white or Color(155,155,155))
        btn:SetText(labels[i])
        btn.Paint = function(self, bw, bh) paintButton(self, bw, bh, enabled) end
        btn.DoClick = function()
            if !enabled then return end
            net.Start("gblackjack_derma_blackjackAction", false)
                net.WriteEntity(self)
                net.WriteUInt(actions[i], 2)
            net.SendToServer()
            win:Remove()
        end
    end
end

function ENT:openLeaveRequest()
    self.leaveRequested = self.leaveRequested or false
    if self.leaveRequested then return else self.leaveRequested = true end

    local w, h = 260, 150
    local win = vgui.Create("DFrame")
    win:SetSize(w,h)
    win:Center()
    win:SetTitle("Leave this table?")
    win:SetDraggable(false)
    win:ShowCloseButton(false)
    win.Paint = function(self, w, h)
        surface.SetDrawColor(feltGreen)
        surface.DrawRect(0,20,w,h-20)
        surface.SetDrawColor(feltHover)
        surface.DrawRect(0,0,w,20)
        surface.DrawOutlinedRect(0,20,w,h-20,2)
    end
    win:SetPopupStayAtBack(true)
    win:MakePopup()

    local y = vgui.Create("DButton", win)
    y:SetFont("gblackjack_header")
    y:SetTextColor(color_white)
    y:SetText("Leave")
    y:SetSize(130,130)
    y:SetPos(0,20)
    y.Paint = function(self, bw, bh) paintButton(self, bw, bh, true) end
    y.DoClick = function()
        self.leaveRequested = false
        win:Close()
        if !IsValid(self) then return end
        net.Start("gblackjack_derma_leaveRequest")
            net.WriteEntity(self)
        net.SendToServer()
    end

    local n = vgui.Create("DButton", win)
    n:SetFont("gblackjack_header")
    n:SetTextColor(color_white)
    n:SetText("Cancel")
    n:SetSize(130,130)
    n:SetPos(130,20)
    n.Paint = function(self, bw, bh) paintButton(self, bw, bh, true) end
    n.DoClick = function()
        self.leaveRequested = false
        if self:GetTurn() == self:getPlayerKey(LocalPlayer()) then self:openBlackjackActionDerma(self.lastBlackjackCanDouble or false) end
        win:Close()
    end
end





