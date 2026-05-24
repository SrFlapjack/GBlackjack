surface.CreateFont("gblackjack_header", {
    font = "Arial",
    extended = false,
    size = 30,
    weight = 1000,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
})

surface.CreateFont("gblackjack_text", {
    font = "Arial",
    extended = false,
    size = 20,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
})


surface.CreateFont("gblackjack_ui_title", {
    font = "Arial",
    extended = false,
    size = 24,
    weight = 900,
    antialias = true,
})

surface.CreateFont("gblackjack_ui_label", {
    font = "Arial",
    extended = false,
    size = 17,
    weight = 700,
    antialias = true,
})

surface.CreateFont("gblackjack_ui_small", {
    font = "Arial",
    extended = false,
    size = 15,
    weight = 500,
    antialias = true,
})
surface.CreateFont("gblackjack_bold", {
    font = "Arial",
    extended = false,
    size = 20,
    weight = 800,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
})

net.Receive("gblackjack_derma_createGame", function()
    local winW, winH = 780, 600
    local win = vgui.Create("DFrame")
    win:SetSize(winW, winH)
    win:Center()
    win:SetTitle("")
    win:SetDraggable(true)
    win:MakePopup()
    local feltDark = Color(8, 30, 20, 245)
    local feltPanel = Color(12, 55, 35, 245)
    local feltPanelLight = Color(19, 82, 52, 245)
    local feltGold = Color(205, 169, 82)
    local feltText = Color(238, 232, 210)
    local feltMuted = Color(190, 184, 162)

    win.Paint = function(_, w, h)
        surface.SetDrawColor(feltDark)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(feltGold)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        surface.DrawRect(0, 30, w, 2)
        draw.SimpleText("GBlackjack Settings", "gblackjack_ui_title", 14, 15, feltText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local function paintInset(panel, w, h)
        surface.SetDrawColor(feltPanel)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(Color(feltGold.r, feltGold.g, feltGold.b, 175))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local function paintButton(btn, w, h)
        local enabled = btn:IsEnabled()
        local hovered = btn:IsHovered()
        if !enabled then
            surface.SetDrawColor(36, 48, 40, 230)
        elseif hovered then
            surface.SetDrawColor(28, 118, 73, 245)
        else
            surface.SetDrawColor(feltPanelLight)
        end
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(feltGold)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local function styleButton(btn, accent)
        btn:SetFont("gblackjack_ui_label")
        btn:SetTextColor(accent and Color(12, 35, 23) or feltText)
        btn.Paint = function(self, w, h)
            if accent then
                surface.SetDrawColor(self:IsHovered() and Color(218, 180, 84) or feltGold)
                surface.DrawRect(0, 0, w, h)
                return
            end

            if self.Active then
                surface.SetDrawColor(26, 115, 72, 245)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(feltGold)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
                return
            end

            paintButton(self, w, h)
        end
    end

    local function styleLabel(label)
        label:SetFont("gblackjack_ui_label")
        label:SetTextColor(feltText)
    end

    local function styleControl(ctrl)
        if ctrl.SetFont then ctrl:SetFont("gblackjack_ui_small") end
        ctrl:SetTall(28)
    end

    local left = vgui.Create("DPanel", win)
    left:SetSize(150)
    left:Dock(LEFT)
    left:DockMargin(10, 8, 0, 10)

    local nav = vgui.Create("DPanel", left)
    nav:Dock(FILL)
    nav:DockMargin(2, 2, 2, 2)
    nav.Paint = nil

    local function makeNavButton(text)
        local btn = vgui.Create("DButton", nav)
        btn:Dock(TOP)
        btn:DockMargin(8, 8, 8, 0)
        btn:SetTall(42)
        btn:SetText(text)
        styleButton(btn)
        return btn
    end

    local gameOption = makeNavButton("Table")
    local betOption = makeNavButton("Wagers")
    local botOption = makeNavButton("Bots")
    local createButton = vgui.Create("DButton", left)
    createButton:Dock(BOTTOM)
    createButton:DockMargin(8, 8, 8, 10)
    createButton:SetText("Create Table")
    createButton:SetTall(48)
    styleButton(createButton, true)

    local right = vgui.Create("DPanel", win)
    right:Dock(FILL)
    right:DockMargin(10, 8, 10, 10)

    local gamePanel = vgui.Create("DPanel", right)
    gamePanel:Dock(FILL)

    local gameSelectText = vgui.Create("DLabel", gamePanel)
    styleLabel(gameSelectText)
    gameSelectText:SetText("Game")
    gameSelectText:Dock(TOP)
    gameSelectText:DockMargin(18,16,18,3)

    local gameSelect = vgui.Create("DComboBox", gamePanel)
    gameSelect:Dock(TOP)
    gameSelect:DockMargin(18,0,18,0)
    styleControl(gameSelect)
    gameSelect:AddChoice(gBlackjack.gameType[0].name, 0, true)

    local maxPlyText = vgui.Create("DLabel", gamePanel)
    maxPlyText:Dock(TOP)
    maxPlyText:DockMargin(18,14,18,3)
    styleLabel(maxPlyText)
    maxPlyText:SetText("Maximum players")

    local maxPly = vgui.Create("DNumberWang", gamePanel)
    maxPly:Dock(TOP)
    maxPly:DockMargin(18,0,18,0)
    styleControl(maxPly)
    maxPly:SetMinMax(1, 8)
    maxPly:SetValue(4)

    local rules = vgui.Create("DLabel", gamePanel)
    rules:Dock(TOP)
    rules:DockMargin(18,18,18,0)
    rules:SetFont("gblackjack_ui_small")
    rules:SetTextColor(feltMuted)
    rules:SetWrap(true)
    rules:SetTall(44)
    rules:SetText("Customize the table rules for this blackjack game.")

    local hitSoft17 = vgui.Create("DCheckBoxLabel", gamePanel)
    hitSoft17:Dock(TOP)
    hitSoft17:DockMargin(18,12,18,0)
    hitSoft17:SetText("Dealer hits soft 17")
    hitSoft17:SetFont("gblackjack_ui_small")
    hitSoft17:SetTextColor(feltText)
    hitSoft17:SetTooltip("Off by default: dealer stands on all 17s.")

    local allowDouble = vgui.Create("DCheckBoxLabel", gamePanel)
    allowDouble:Dock(TOP)
    allowDouble:DockMargin(18,7,18,0)
    allowDouble:SetText("Allow double down")
    allowDouble:SetFont("gblackjack_ui_small")
    allowDouble:SetTextColor(feltText)
    allowDouble:SetValue(1)

    local payoutText = vgui.Create("DLabel", gamePanel)
    payoutText:Dock(TOP)
    payoutText:DockMargin(18,16,18,3)
    styleLabel(payoutText)
    payoutText:SetText("Blackjack payout")

    local payoutSelect = vgui.Create("DComboBox", gamePanel)
    payoutSelect:Dock(TOP)
    payoutSelect:DockMargin(18,0,18,0)
    styleControl(payoutSelect)
    for i = 0, #gBlackjack.blackjackPayouts do
        payoutSelect:AddChoice(gBlackjack.blackjackPayouts[i].name, i, i == 0)
    end

    local betPanel = vgui.Create("DPanel", right)
    betPanel:Dock(FILL)
    betPanel:Hide()

    local betText = vgui.Create("DLabel", betPanel)
    betText:Dock(TOP)
    betText:DockMargin(18,16,18,3)
    styleLabel(betText)
    betText:SetText("Wager Type")

    local betSelect = vgui.Create("DComboBox", betPanel)
    betSelect:Dock(TOP)
    betSelect:DockMargin(18,0,18,0)
    styleControl(betSelect)
    for i = 0, #gBlackjack.betType do
        local betType = gBlackjack.betType[i]
        if !betType.canUse or betType.canUse() then
            betSelect:AddChoice(betType.name, i, i == 0)
        end
    end

    local entryFee = vgui.Create("DNumSlider", betPanel)
    entryFee:Dock(TOP)
    entryFee:DockMargin(18,18,18,0)
    entryFee:SetText("Minimum Wager")
    entryFee:SetDark(false)
    entryFee:SetDecimals(0)

    local startValue = vgui.Create("DNumSlider", betPanel)
    startValue:Dock(TOP)
    startValue:DockMargin(18,18,18,0)
    startValue:SetText("Starting Value")
    startValue:SetDark(false)
    startValue:SetDecimals(0)
    startValue:SetMinMax(gBlackjack.betType[0].setMinMax.min, gBlackjack.betType[0].setMinMax.max)
    startValue:SetValue(startValue:GetMax()/10)

    local function refreshEntryWagerLimit()
        local betType = gBlackjack.betType[betSelect:GetOptionData(betSelect:GetSelectedID()) or 0]
        local max = betType.feeMinMax.max(startValue) or 1
        entryFee:SetMinMax(math.max(1, betType.feeMinMax.min or 1), math.max(1, max))
        if entryFee:GetValue() < 1 then entryFee:SetValue(1) end
        if entryFee:GetValue() > entryFee:GetMax() then entryFee:SetValue(entryFee:GetMax()) end
    end

    local function refreshBetTypeControls()
        local betType = gBlackjack.betType[betSelect:GetOptionData(betSelect:GetSelectedID()) or 0]
        startValue:SetMinMax(betType.setMinMax.min, betType.setMinMax.max)
        if betType.canSet then startValue:Show() else startValue:Hide() end
        refreshEntryWagerLimit()
    end

    startValue.OnValueChanged = refreshEntryWagerLimit
    betSelect.OnSelect = refreshBetTypeControls
    refreshBetTypeControls()
    entryFee:SetValue(math.max(1, math.floor(entryFee:GetMax() / 10)))

    local function paintSettingsPanel(panel, w, h)
        paintInset(panel, w, h)
    end

    left.Paint = paintSettingsPanel
    right.Paint = paintSettingsPanel
    gamePanel.Paint = paintSettingsPanel
    betPanel.Paint = paintSettingsPanel

    local botPanel = vgui.Create("DPanel", right)
    botPanel:Dock(FILL)
    botPanel.Paint = paintSettingsPanel
    botPanel:Hide()

    local placeholder = vgui.Create("DCheckBoxLabel", botPanel)
    placeholder:Dock(TOP)
    placeholder:DockMargin(18,16,18,0)
    placeholder:SetText("AI seats can be replaced")
    placeholder:SetFont("gblackjack_ui_small")
    placeholder:SetTextColor(feltText)
    placeholder:SetTooltip("When the table is full, a joining player takes an AI seat")

    local botsList = vgui.Create("DListView", botPanel)
    botsList:Dock(TOP)
    botsList:DockMargin(18,10,18,0)
    botsList:SetTall(170)
    botsList:AddColumn("Name", 1)
    botsList:AddColumn("Model", 2)
    botsList:AddColumn("Color", 3)
    botsList:AddColumn("Style", 4)

    local botEditor = vgui.Create("DPanel", botPanel)
    botEditor:Dock(TOP)
    botEditor:DockMargin(18, 12, 18, 0)
    botEditor:SetTall(260)
    botEditor.Paint = nil

    local botPreview = vgui.Create("DModelPanel", botEditor)
    botPreview:Dock(RIGHT)
    botPreview:DockMargin(14, 0, 0, 0)
    botPreview:SetWide(190)
    botPreview:SetModel("models/player/kleiner.mdl")
    botPreview.LayoutEntity = function(_, ent) ent:SetAngles(Angle(0, 35, 0)) end
    local botPreviewPaint = botPreview.Paint
    botPreview.Paint = function(self, w, h)
        surface.SetDrawColor(8, 30, 20, 245)
        surface.DrawRect(0, 0, w, h)
        botPreviewPaint(self, w, h)
        surface.SetDrawColor(feltGold)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local botForm = vgui.Create("DPanel", botEditor)
    botForm:Dock(FILL)
    botForm.Paint = nil

    local botName = vgui.Create("DTextEntry", botForm)
    botName:Dock(TOP)
    botName:SetPlaceholderText("Bot name")
    styleControl(botName)

    local botStyle = vgui.Create("DComboBox", botForm)
    botStyle:Dock(TOP)
    botStyle:DockMargin(0, 8, 0, 0)
    styleControl(botStyle)
    for i = 1, #gBlackjack.botStyles do
        botStyle:AddChoice(gBlackjack.botStyles[i].name, i, i == 2)
    end

    local botModel = vgui.Create("DComboBox", botForm)
    botModel:Dock(TOP)
    botModel:DockMargin(0, 8, 0, 0)
    styleControl(botModel)
    local validModels = player_manager.AllValidModels()
    local botModelOptionCount = 0
    for name, mdl in SortedPairs(validModels) do
        botModelOptionCount = botModelOptionCount + 1
        botModel:AddChoice(name, mdl, mdl == "models/player/kleiner.mdl")
    end

    local botColor = vgui.Create("DColorMixer", botForm)
    botColor:Dock(FILL)
    botColor:DockMargin(0, 6, 0, 0)
    botColor:SetAlphaBar(false)
    botColor:SetPalette(false)
    botColor:SetWangs(false)
    botColor:SetColor(Color(255, 255, 255))

    local function chooseBotModel(mdl)
        for i = 1, botModelOptionCount do
            if botModel:GetOptionData(i) == mdl then
                botModel:ChooseOptionID(i)
                return
            end
        end
    end

    local function vectorToColor(vec)
        vec = vec or Vector(1, 1, 1)
        return Color((vec.x or 1) * 255, (vec.y or 1) * 255, (vec.z or 1) * 255)
    end

    local botButtons = vgui.Create("DPanel", botPanel)
    botButtons:Dock(TOP)
    botButtons:DockMargin(18, 12, 18, 0)
    botButtons:SetTall(32)
    botButtons.Paint = nil

    local botAdd = vgui.Create("DButton", botButtons)
    botAdd:Dock(LEFT)
    botAdd:SetWide(86)
    botAdd:SetText("Add AI")
    styleButton(botAdd)

    local botApply = vgui.Create("DButton", botButtons)
    botApply:Dock(LEFT)
    botApply:DockMargin(6,0,0,0)
    botApply:SetWide(86)
    botApply:SetText("Apply")
    botApply:SetEnabled(false)
    styleButton(botApply)

    local botRemove = vgui.Create("DButton", botButtons)
    botRemove:Dock(LEFT)
    botRemove:DockMargin(6,0,0,0)
    botRemove:SetWide(90)
    botRemove:SetText("Remove")
    botRemove:SetEnabled(false)
    styleButton(botRemove)

    local autoFill = vgui.Create("DButton", botButtons)
    autoFill:Dock(LEFT)
    autoFill:DockMargin(6,0,0,0)
    autoFill:SetWide(76)
    autoFill:SetText("Fill AI")
    styleButton(autoFill)

    local bots = {}

    local function selectedBot()
        local selected = botsList:GetSelected()
        local line = selected and selected[1]
        if !IsValid(line) then return nil end

        for key, val in pairs(bots) do
            if val.panel == line then return val, key, line end
        end
    end

    local function refreshBotEditor()
        local bot = selectedBot()
        local hasBot = bot != nil
        botRemove:SetEnabled(hasBot)
        botApply:SetEnabled(hasBot)

        if hasBot then
            botName:SetText(bot.name or "")
            botStyle:ChooseOptionID(bot.aiStyle or 2)
            chooseBotModel(bot.mdl)
            botColor:SetColor(vectorToColor(bot.clr))
            botPreview:SetModel(bot.mdl or "models/player/kleiner.mdl")
            botPreview.Entity.GetPlayerColor = function() return bot.clr or Vector(1, 1, 1) end
        end
    end

    local function addBotLine(name, mdl, clr, aiStyle)
        aiStyle = aiStyle or math.random(1, #gBlackjack.botStyles)
        local style = gBlackjack.botStyles[aiStyle] or gBlackjack.botStyles[2]
        local color = vectorToColor(clr)
        local line = botsList:AddLine(name, mdl, color, style.name)
        line.OnSelect = refreshBotEditor
        bots[#bots + 1] = {name = name, mdl = mdl, clr = clr, aiStyle = aiStyle, panel = line}
    end

    botAdd.DoClick = function()
        if #bots >= math.Clamp(maxPly:GetValue(), maxPly:GetMin(), maxPly:GetMax()) then return end

        local name = botName:GetValue() != "" and botName:GetValue() or table.Random(gBlackjack.bots.names)
        local mdl = botModel:GetOptionData(botModel:GetSelectedID()) or table.Random(player_manager.AllValidModels())
        local pickedColor = botColor:GetColor()
        local clr = Vector(pickedColor.r / 255, pickedColor.g / 255, pickedColor.b / 255)
        local aiStyle = botStyle:GetOptionData(botStyle:GetSelectedID()) or math.random(1, #gBlackjack.botStyles)
        botPreview:SetModel(mdl)
        botPreview.Entity.GetPlayerColor = function() return clr end
        addBotLine(name, mdl, clr, aiStyle)
    end

    botApply.DoClick = function()
        local bot, _, line = selectedBot()
        if !bot then return end

        bot.name = botName:GetValue() != "" and botName:GetValue() or bot.name
        bot.aiStyle = botStyle:GetOptionData(botStyle:GetSelectedID()) or bot.aiStyle or 2
        bot.mdl = botModel:GetOptionData(botModel:GetSelectedID()) or bot.mdl
        local pickedColor = botColor:GetColor()
        bot.clr = Vector(pickedColor.r / 255, pickedColor.g / 255, pickedColor.b / 255)
        botPreview:SetModel(bot.mdl or "models/player/kleiner.mdl")
        botPreview.Entity.GetPlayerColor = function() return bot.clr or Vector(1, 1, 1) end
        local style = gBlackjack.botStyles[bot.aiStyle] or gBlackjack.botStyles[2]
        line:SetColumnText(1, bot.name)
        line:SetColumnText(2, bot.mdl)
        line:SetColumnText(3, vectorToColor(bot.clr))
        line:SetColumnText(4, style.name)
    end

    autoFill.DoClick = function()
        while #bots < math.Clamp(maxPly:GetValue(), maxPly:GetMin(), maxPly:GetMax()) do
            addBotLine(table.Random(gBlackjack.bots.names), table.Random(player_manager.AllValidModels()), Vector(math.random(), math.random(), math.random()), math.random(1, #gBlackjack.botStyles))
        end
    end
    maxPly.OnValueChanged = function()
        while #bots > maxPly:GetValue() do
            local bot = table.remove(bots)
            if IsValid(bot.panel) then botsList:RemoveLine(bot.panel:GetID()) end
            refreshBotEditor()
        end
    end

    botRemove.DoClick = function()
        local selected = botsList:GetSelected()
        for k,v in pairs(selected) do
            for key, val in pairs(bots) do
                if val.panel == v then table.remove(bots, key) break end
            end
            botsList:RemoveLine(v:GetID())
        end
        refreshBotEditor()
    end

    local function showPanel(active)
        gamePanel:SetVisible(active == gameOption)
        betPanel:SetVisible(active == betOption)
        botPanel:SetVisible(active == botOption)
        gameOption.Active = active == gameOption
        betOption.Active = active == betOption
        botOption.Active = active == botOption
    end

    gameOption.DoClick = function() showPanel(gameOption) end
    betOption.DoClick = function() showPanel(betOption) end
    botOption.DoClick = function() showPanel(botOption) end
    showPanel(gameOption)

    createButton.DoClick = function()
        for k,v in pairs(bots) do v.panel = nil end

        local options = {
            game = {
                type = 0,
                maxPly = math.Clamp(maxPly:GetValue(), 1, 8)
            },
            bet = {
                type = betSelect:GetOptionData(betSelect:GetSelectedID()) or 0,
                entry = math.max(1, math.floor(entryFee:GetValue())),
                start = math.floor(startValue:GetValue()) or 0
            },
            rules = {
                hitSoft17 = hitSoft17:GetChecked(),
                allowDouble = allowDouble:GetChecked(),
                payout = payoutSelect:GetOptionData(payoutSelect:GetSelectedID()) or 0
            },
            bot = {
                placehold = placeholder:GetChecked(),
                list = bots
            }
        }

        net.Start("gblackjack_derma_createGame")
            net.WriteTable(options)
        net.SendToServer()

        win:Remove()
    end
end)

net.Receive("gblackjack_updatePlayers", function()
    local ent = net.ReadEntity()
    if !IsValid(ent) then return end
    ent.players = net.ReadTable()
end)

net.Receive("gblackjack_sendDeck", function()
    local ent = net.ReadEntity()
    local community = net.ReadBool()
    local deck = net.ReadTable()

    if !IsValid(ent) then return end
    if community then ent.communityDeck = deck else ent.localDeck = deck end
end)

net.Receive("gblackjack_derma_blackjackWager", function()
    local ent = net.ReadEntity()
    local minWager = net.ReadFloat()
    local maxWager = net.ReadFloat()

    if !IsValid(ent) then return end
    ent:openBlackjackWagerDerma(minWager, maxWager)
end)

net.Receive("gblackjack_derma_blackjackAction", function()
    local ent = net.ReadEntity()
    local canDouble = net.ReadBool()

    if !IsValid(ent) then return end
    ent:openBlackjackActionDerma(canDouble)
end)

hook.Add("KeyPress", "gblackjack_leaveRequest", function(ply, key)
    if key == IN_USE and ply:InVehicle() and ply:GetVehicle():GetVehicleClass() == "Chair_Office2" and IsValid(ply:GetVehicle():GetParent()) and ply:GetVehicle():GetParent():GetClass() == "ent_blackjack_game" then
        if LocalPlayer() == ply then ply:GetVehicle():GetParent():openLeaveRequest() end
    end
end)



