local Angle = Angle
local hook = hook
local net = net
local pairs = pairs
local player = player
local render = render
local table = table
local vgui = vgui

local AddHook = hook.Add
local PlayerIterator = player.Iterator
local TableInsert = table.insert

local client
local target
local dtargetbox
local dcredits
local cameraFrame
local renderingCamView = false
local buttons = {}

------------------
-- ROLE CONVARS --
------------------

local puppeteer_command_fire_duration = GetConVar("ttt_puppeteer_command_fire_duration")
local puppeteer_debuff_pinata_count = GetConVar("ttt_puppeteer_debuff_pinata_count")

-------------------
-- ROLE FEATURES --
-------------------

surface.CreateFont("PuppeteerTitle", {
    font = "Tahoma",
    size = 15,
    weight = 750
})
surface.CreateFont("PuppeteerDesc", {
    font = "Tahoma",
    size = 13,
    weight = 550
})

local function UpdateState(enabled)
    if not IsPlayer(client) then return end
    if not client:IsActivePuppeteer() then return end

    for _, btn in pairs(buttons) do
        local btnEnabled = enabled and (not btn.EnablePredicate or btn:EnablePredicate())
        btn:SetEnabled(btnEnabled)
        if btn.label then
            local btnSkin = btn:GetSkin()
            local color = btnEnabled and btnSkin.Colours.Button.Normal or btnSkin.Colours.Button.Disabled
            btn:SetColor(color)
            btn.label:SetTextColor(color)
        end
    end

    if IsValid(dcredits) then
        dcredits:UpdateState()
    end
end

local function CreateCamera()
    if not IsValid(cameraFrame) then
        cameraFrame = vgui.Create("DFrame")
        cameraFrame:SetSize(ScrW() / 5, ScrH() / 5)
        cameraFrame:SetPos(0, 0)
        cameraFrame:SetDraggable(true)
        cameraFrame:SetSizable(true)
        function cameraFrame:Paint()
            if not IsValid(self) then return end
            if not IsPlayer(target) then return end

            local x, y, w, h = self:GetBounds()
            local eyeAngles = target:EyeAngles()

            renderingCamView = true
            render.RenderView({
                origin = target:GetBonePosition(target:LookupBone("ValveBiped.Bip01_Head1")),
                znear = 7,
                fov = 65,
                angles = Angle(eyeAngles.pitch, eyeAngles.yaw, 0),
                x = x,
                y = y,
                w = w,
                h = h
            })
            renderingCamView = false
        end
    end

    cameraFrame:SetTitle(LANG.GetParamTranslation("puppeteer_puppet_target_window", { target = target:Nick() }))
end

local function ClearCamera()
    if cameraFrame then
        cameraFrame:Remove()
        cameraFrame = nil
    end
end

local function SetTarget(ply)
    target = ply
    UpdateState(true)
    CreateCamera()
end

local function DebuffTarget(debuff)
    -- Set these properties immediately on the client so we can disable the buttons
    target.TTTPuppeteerDebuffed = true
    target.TTTPuppeteerDebuff = debuff
    UpdateState(true)

    -- Tell the server so everyone gets notified about the debuff
    net.Start("TTT_PuppeteerSetDebuff")
        net.WritePlayer(target)
        net.WriteUInt(debuff, 3)
    net.SendToServer()
end

local function ClearTarget()
    net.Start("TTT_PuppeteerClearDebuff")
        net.WritePlayer(target)
    net.SendToServer()

    target = nil
    UpdateState(false)
    ClearCamera()
end

local function CreateDebuffButton(text, tip, onclick, pred, parent, w, h, image, padding)
    local dbutton = vgui.Create("DImageButton", parent)
    dbutton:SetTooltip(tip)
    dbutton:SetSize(w, 32 + h + padding)
    dbutton:SetStretchToFit(false)
    function dbutton.m_Image:SizeToContents()
        self:SetSize(32, 32)
    end
    function dbutton.m_Image:Center()
        DImage.Center(self)
        self:SetY(self:GetY() - padding)
    end
    dbutton:SetImage("vgui/ttt/roles/pup/32_" .. image .. ".png")
    dbutton:SetPaintBackground(true)
    dbutton:SetDrawBorder(true)

    local btnSkin = dbutton:GetSkin()
    dbutton:SetColor(btnSkin.Colours.Button.Disabled)
    dbutton:SetEnabled(false)

    local dlabel = vgui.Create("DLabel", dbutton)
    dlabel:SetText(text)
    dlabel:SetColor(btnSkin.Colours.Button.Disabled)
    dlabel:SizeToContents()
    dlabel:Center()
    dlabel:SetY(h + (padding * 2))
    dbutton.label = dlabel

    dbutton.EnablePredicate = function()
        if not IsPlayer(target) then return false end
        if not IsPlayer(client) or not client:IsActivePuppeteer() then return false end
        if client:GetCredits() <= 0 then return false end
        if not pred or type(pred) ~= "function" then return true end

        return pred()
    end
    dbutton.DoClick = function()
        if not IsPlayer(target) then return end
        if not IsPlayer(client) or not client:IsActivePuppeteer() then return end
        if client:GetCredits() <= 0 then return end

        onclick()
    end

    TableInsert(buttons, dbutton)

    return dbutton
end

local function DebuffPredicate()
    if target.TTTPuppeteerDebuffed then return false end
    return true
end

local function UpdateTargetsList(skip)
    if not IsValid(dtargetbox) then return end
    local _, selected = dtargetbox:GetSelected()
    dtargetbox:Clear()
    dtargetbox:SetValue(LANG.GetTranslation("puppeteer_puppet_target_placeholder"))
    for _, p in PlayerIterator() do
        -- TODO: Undo this
        if --[[p == client or]] p == skip then continue end
        if not IsPlayer(p) then continue end
        if not p:Alive() or p:IsSpec() then continue end
        if p:IsDetectiveTeam() --[[or p:IsTraitorTeam()]] or p:IsGlitch() or p:IsJesterTeam() then continue end

        local sid64 = p:SteamID64()
        dtargetbox:AddChoice(p:Nick(), sid64, sid64 == selected)
    end
end

AddHook("TTTEquipmentTabs", "Puppeteer_TTTEquipmentTabs", function(dsheet, dframe)
    if not client then
        client = LocalPlayer()
    end

    if not client:IsActivePuppeteer() then return end

    buttons = {}

    local padding = dsheet:GetPadding()
    local tabHeight = 20
    local T = LANG.GetTranslation
    local PT = LANG.GetParamTranslation

    local dform = vgui.Create("DForm", dsheet)
    dform:SetName(T("puppeteer_puppet_target_label"))
    dform:StretchToParent(padding, padding + tabHeight, padding, padding)
    dform:SetAutoSize(false)

    dtargetbox = vgui.Create("DComboBox", dform)
    UpdateTargetsList()
    function dtargetbox:OnSelect(idx, val, data)
        local tgt = player.GetBySteamID64(data)
        local disabled = (not data or #data == 0) or not IsPlayer(tgt)
        if disabled then
            ClearTarget()
        else
            SetTarget(tgt)
        end
    end
    dform:AddItem(dtargetbox)

    local oldFrameClose = dframe.OnClose
    function dframe:OnClose(...)
        if oldFrameClose then
            oldFrameClose(self, ...)
        end

        ClearTarget()
        buttons = {}
    end

    local div = vgui.Create("DHorizontalDivider", dform)
    div:SetSize(dsheet:GetWide(), 2)
    div:SetPaintBackground(true)
    div:SetBackgroundColor(COLOR_LGRAY)
    div:SetY(dtargetbox:GetTall() + (padding * 2) + tabHeight)

    local buttonY = 70
    local dlabel = vgui.Create("DLabel", dform)
    dlabel:SetText(T("puppeteer_puppet_actions"))
    dlabel:SetFont("PuppeteerTitle")
    dlabel:SetColor(COLOR_DGRAY)
    dlabel:SetPos(padding, buttonY)

    buttonY = buttonY + dlabel:GetTall() + padding
    local buttonWidth = ((dform:GetWide() - (padding * 4)) / 3)
    local buttonHeight = 25

    local fire_duration = puppeteer_command_fire_duration:GetFloat()

    local dfire = vgui.Create("DButton", dform)
    dfire:SetText(PT("puppeteer_puppet_fire_weapon", { time = fire_duration }))
    dfire:SetSize(buttonWidth, buttonHeight)
    dfire:SetEnabled(false)
    dfire.EnablePredicate = function()
        if not IsPlayer(target) then return false end
        if not IsPlayer(client) or not client:IsActivePuppeteer() then return false end
        return true
    end
    dfire.DoClick = function()
        -- TODO
    end
    -- MoveBelow doesn't seem to be working for this, so do it manually
    dfire:SetPos(padding, buttonY)
    TableInsert(buttons, dfire)

    buttonY = buttonY + buttonHeight + padding

    div = vgui.Create("DHorizontalDivider", dform)
    div:SetSize(dsheet:GetWide(), 2)
    div:SetPaintBackground(true)
    div:SetBackgroundColor(COLOR_LGRAY)
    div:SetY(buttonY)

    buttonY = buttonY + div:GetTall() + padding

    dlabel = vgui.Create("DLabel", dform)
    dlabel:SetText(T("puppeteer_puppet_debuffs"))
    dlabel:SetFont("PuppeteerTitle")
    dlabel:SetColor(COLOR_DGRAY)
    dlabel:SetPos(padding, buttonY)

    buttonY = buttonY + dlabel:GetTall() - padding

    dlabel = vgui.Create("DLabel", dform)
    dlabel:SetText(T("puppeteer_puppet_debuffs_desc"))
    dlabel:SetFont("PuppeteerDesc")
    dlabel:SetWide(dform:GetWide())
    dlabel:SetColor(COLOR_DGRAY)
    dlabel:SetPos(padding, buttonY)

    buttonY = buttonY + dlabel:GetTall() + padding

    local pinata_count = puppeteer_debuff_pinata_count:GetInt()
    local dpinata = CreateDebuffButton(T("puppeteer_puppet_debuff_0"), PT("puppeteer_puppet_debuff_0_tip", { num = pinata_count, traitor = T("traitor") }),
        -- DoClick
        function()
            -- TODO
            DebuffTarget(PUPPETEER_DEBUFF_TYPE_PINATA)
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight, "pinata", padding)
    dpinata:SetPos(padding, buttonY)

    local dspoilsport = CreateDebuffButton(T("puppeteer_puppet_debuff_1"), T("puppeteer_puppet_debuff_1_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget(PUPPETEER_DEBUFF_TYPE_SPOILSPORT)
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight, "spoilsport", padding)
    dspoilsport:SetY(buttonY)
    dspoilsport:MoveRightOf(dpinata, padding)

    local dcopycat = CreateDebuffButton(T("puppeteer_puppet_debuff_2"), T("puppeteer_puppet_debuff_2_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget(PUPPETEER_DEBUFF_TYPE_COPYCAT)
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight, "copycat", padding)
    dcopycat:SetY(buttonY)
    dcopycat:MoveRightOf(dspoilsport, padding)

    local dredherring = CreateDebuffButton(T("puppeteer_puppet_debuff_3"), PT("puppeteer_puppet_debuff_3_tip", { atraitor = ROLE_STRINGS_EXT[ROLE_TRAITOR] }),
        -- DoClick
        function()
            -- TODO
            DebuffTarget(PUPPETEER_DEBUFF_TYPE_REDHERRING)
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight, "redherring", padding)
    dredherring:MoveBelow(dpinata, padding)
    dredherring:SetX((buttonWidth / 2) + (padding * 2))

    local dwanderer = CreateDebuffButton(T("puppeteer_puppet_debuff_4"), T("puppeteer_puppet_debuff_4_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget(PUPPETEER_DEBUFF_TYPE_WANDERER)
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight, "wanderer", padding)
    dwanderer:MoveBelow(dpinata, padding)
    dwanderer:MoveRightOf(dredherring, padding)

    dcredits = vgui.Create("DPanel", dform)
    dcredits:SetPaintBackground(false)
    dcredits:SetHeight(32)
    dcredits:SetPos(padding, dform:GetTall() - dcredits:GetTall() - padding)

    dcredits.img = vgui.Create("DImage", dform)
    dcredits.img:SetSize(32, 32)
    dcredits.img:CopyPos(dcredits)
    dcredits.img:SetImage("vgui/ttt/equip/coin.png")

    dcredits.lbl = vgui.Create("DLabel", dform)
    dcredits.lbl:SetFont("DermaLarge")
    dcredits.lbl:CopyPos(dcredits)
    dcredits.lbl:MoveRightOf(dcredits.img)

    function dcredits:UpdateState()
        local credits = client:GetCredits()
        local result = credits > 0
        local text = " " .. credits
        local tooltip = PT("equip_cost", { num = credits })

        self.lbl:SetTextColor(result and COLOR_WHITE or COLOR_RED)
        self.lbl:SetText(text)
        self.lbl:SizeToContents()

        self.img:SetImageColor(result and COLOR_WHITE or COLOR_RED)

        self:SetTooltip(tooltip)
    end
    dcredits:UpdateState()

    local added = dsheet:AddSheet(LANG.GetTranslation("puppeteer_puppet_menu_name"), dform, "icon16/television.png", false, false, LANG.GetTranslation("puppeteer_puppet_menu_tip"))
    dsheet:SetActiveTab(added.Tab)
    return true
end)

AddHook("ShouldDrawLocalPlayer", "Puppeteer_ShouldDrawLocalPlayer", function(ply)
    if renderingCamView then return true end
end)

net.Receive("TTT_PuppeteerPlayerDeath", function()
    if not client then
        client = LocalPlayer()
    end

    local ply = net.ReadPlayer()
    if IsPlayer(ply) and target == ply then
        client:QueueMessage(MSG_PRINTBOTH, "Your target (\"" .. ply:Nick() .. "\") has died!")
        ClearTarget()
    end
    UpdateTargetsList(ply)
end)

net.Receive("TTT_PuppeteerDeath", ClearTarget)
net.Receive("TTT_PuppeteerRoleChange", function()
    if not client then
        client = LocalPlayer()
    end

    local ply = net.ReadPlayer()
    if IsPlayer(ply) and target == ply then
        client:QueueMessage(MSG_PRINTBOTH, "Your target (\"" .. ply:Nick() .. "\") is no longer a viable target!")
        ClearTarget()
    end
    UpdateTargetsList()
end)

AddHook("TTTPrepareRound", "Puppeteer_TTTPrepareRound", function()
    target = nil
    ClearCamera()
end)

---------
-- HUD --
---------

local icon_tex = {
    [PUPPETEER_DEBUFF_TYPE_PINATA] = Material("vgui/ttt/roles/pup/16_pinata.png"),
    [PUPPETEER_DEBUFF_TYPE_SPOILSPORT] = Material("vgui/ttt/roles/pup/16_spoilsport.png"),
    [PUPPETEER_DEBUFF_TYPE_COPYCAT] = Material("vgui/ttt/roles/pup/16_copycat.png"),
    [PUPPETEER_DEBUFF_TYPE_REDHERRING] = Material("vgui/ttt/roles/pup/16_redherring.png"),
    [PUPPETEER_DEBUFF_TYPE_WANDERER] = Material("vgui/ttt/roles/pup/16_wanderer.png")
}

AddHook("TTTHUDInfoPaint", "Puppeteer_TTTHUDInfoPaint", function(cli, label_left, label_top, active_labels)
    if not cli.TTTPuppeteerDebuffed then return end

    surface.SetFont("TabLarge")
    surface.SetTextColor(255, 255, 255, 230)

    local text = LANG.GetParamTranslation("puppeteer_hud", { debuff = LANG.GetTranslation("puppeteer_puppet_debuff_" .. cli.TTTPuppeteerDebuff), puppeteer = ROLE_STRINGS[ROLE_PUPPETEER] })
    local _, h = surface.GetTextSize(text)

    -- Move this up based on how many other labels there are
    label_top = label_top + (20 * #active_labels)

    local icon_x, icon_y = 16, 16
    surface.SetMaterial(icon_tex[cli.TTTPuppeteerDebuff])
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(label_left, ScrH() - label_top - icon_y, icon_x, icon_y)

    label_left = label_left + 20

    surface.SetTextPos(label_left, ScrH() - label_top - h)
    surface.DrawText(text)

    -- Reset this back to where it was
    label_left = label_left - 20

    -- Track that the label was added so others can position accurately
    TableInsert(active_labels, "puppeteer")
end)

-------------
-- DEBUFFS --
-------------

-- Red Herring --

AddHook("TTTShowSearchScreen", "Puppeteer_TTTShowSearchScreen", function(search)
    if not IsPlayer(search.owner) then return end
    if search.owner.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_REDHERRING then return end

    if search.role == ROLE_INNOCENT then
        search.role = ROLE_PUPPETEER
    else
        search.role = ROLE_TRAITOR
    end

    search.team = player.GetRoleTeam(search.role)
end)

------------
-- EVENTS --
------------

AddHook("TTTSyncEventIDs", "Puppeteer_TTTSyncEventIDs", function()
    EVENT_PUPPETEERDEBUFFED = EVENTS_BY_ROLE[ROLE_PUPPETEER]
    local debuff_icon = Material("icon16/emoticon_unhappy.png")
    local Event = CLSCORE.DeclareEventDisplay
    local PT = LANG.GetParamTranslation
    Event(EVENT_PUPPETEERDEBUFFED, {
        text = function(e)
            return PT("ev_puppeteerdebuffed", {victim = e.vic, attacker = e.att, debuff = e.deb})
        end,
        icon = function(e)
            return debuff_icon, "Debuffed"
        end})
end)

net.Receive("TTT_PuppeteerDebuffed", function(len)
    local attacker = net.ReadPlayer()
    local victim = net.ReadPlayer()
    local debuff = net.ReadUInt(3)

    if not IsPlayer(victim) or not IsPlayer(attacker) then return end

    local eventData = {
        id = EVENT_PUPPETEERDEBUFFED,
        vic = victim:Nick(),
        att = attacker:Nick(),
        deb = LANG.GetTranslation("puppeteer_puppet_debuff_" .. debuff)
    }
    CLSCORE:AddEvent(eventData)

    if not client then
        client = LocalPlayer()
    end

    if victim == client then
        local message = LANG.GetParamTranslation("ev_puppeteerdebuffed", { attacker = string.Capitalize(ROLE_STRINGS_EXT[ROLE_PUPPETEER]), victim = LANG.GetTranslation("puppeteer_puppet_target_you"), debuff = eventData.deb })
        client:QueueMessage(MSG_PRINTBOTH, message)
    elseif client ~= attacker and client:IsTraitorTeam() then
        local message = LANG.GetParamTranslation("ev_puppeteerdebuffed", { attacker = eventData.att, victim = eventData.vic, debuff = eventData.deb })
        client:QueueMessage(MSG_PRINTBOTH, message)
    end

    -- Update the button state if we have a target, just in case someone else debuffed them
    if client:IsActivePuppeteer() and IsPlayer(target) then
        UpdateState(true)
    end
end)

--------------
-- TUTORIAL --
--------------

AddHook("TTTTutorialRoleText", "Puppeteer_TTTTutorialRoleText", function(role, titleLabel)
    if role == ROLE_PUPPETEER then
        local roleColor = ROLE_COLORS[ROLE_TRAITOR]
        local html = "The " .. ROLE_STRINGS[ROLE_PUPPETEER] .. " is a a member of the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>traitor team</span whose goal is to control a targeted player, watching their movements and applying negative effects."

        -- TODO

        return html
    end
end)