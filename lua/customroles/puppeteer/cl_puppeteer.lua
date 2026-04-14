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
local cameraFrame
local renderingCamView = false
local buttons = {}

------------------
-- ROLE CONVARS --
------------------

local puppeteer_command_fire_duration = GetConVar("ttt_puppeteer_command_fire_duration")

-------------------
-- ROLE FEATURES --
-------------------

local function UpdateButtonState(enabled)
    for _, btn in pairs(buttons) do
        btn:SetEnabled(enabled and (not btn.EnablePredicate or btn:EnablePredicate()))
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
    UpdateButtonState(true)
    CreateCamera()
end

local function DebuffTarget()
    net.Start("TTTPuppeteerSetDebuff")
        net.WritePlayer(target)
    net.SendToServer()
end

local function ClearTarget()
    -- TODO: Clear debuff effect
    net.Start("TTTPuppeteerClearDebuff")
        net.WritePlayer(target)
    net.SendToServer()

    target = nil
    UpdateButtonState(false)
    ClearCamera()
end

local function CreateButton(text, tip, onclick, pred, parent, w, h)
    local dbutton = vgui.Create("DButton", parent)
    dbutton:SetText(text)
    dbutton:SetTooltip(tip)
    dbutton:SetSize(w, h)
    dbutton:SetEnabled(false)

    dbutton.EnablePredicate = function()
        if not IsPlayer(target) then return false end
        if not pred or type(pred) ~= "function" then return true end

        return pred()
    end
    dbutton.DoClick = onclick

    TableInsert(buttons, dbutton)

    return dbutton
end

local function DebuffPredicate()
    if target.TTTPuppeteerDebuffed then return false end
end

local function UpdateTargetsList(skip)
    if not IsValid(dtargetbox) then return end
    local _, selected = dtargetbox:GetSelected()
    dtargetbox:Clear()
    dtargetbox:SetValue(LANG.GetTranslation("puppeteer_puppet_target_placeholder"))
    for _, p in PlayerIterator() do
        if p == client or p == skip then continue end
        if not IsPlayer(p) then continue end
        if not p:Alive() or p:IsSpec() then continue end
        if p:IsDetectiveTeam() or p:IsTraitorTeam() or p:IsGlitch() or p:IsJesterTeam() then continue end

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
    div:SetHeight(2)
    div:MoveBelow(dtargetbox)
    div:Dock(FILL)
    div:SetPaintBackground(true)
    div:SetBackgroundColor(COLOR_LGRAY)
    dform:AddItem(div)

    local buttonY = 70
    local buttonWidth = ((dform:GetWide() - (padding * 4)) / 3)
    local buttonHeight = 25

    local fire_duration = puppeteer_command_fire_duration:GetFloat()
    local dfire = CreateButton(PT("puppeteer_puppet_fire_weapon", { time = fire_duration }), nil,
        -- DoClick
        function()
            -- TODO
        end,
        -- EnablePredicate
        nil,
        dform, buttonWidth, buttonHeight)
    -- MoveBelow doesn't seem to be working for this, so do it manually
    dfire:SetPos(padding, buttonY)

    local dpinata = CreateButton(T("puppeteer_puppet_debuff_pinata"), T("puppeteer_puppet_debuff_pinata_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget()
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight)
    dpinata:SetY(buttonY)
    dpinata:MoveRightOf(dfire, padding)

    local dspoilsport = CreateButton(T("puppeteer_puppet_debuff_spoilsport"), T("puppeteer_puppet_debuff_spoilsport_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget()
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight)
    dspoilsport:SetY(buttonY)
    dspoilsport:MoveRightOf(dpinata, padding)

    local dcopycat = CreateButton(T("puppeteer_puppet_debuff_copycat"), T("puppeteer_puppet_debuff_copycat_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget()
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight)
    dcopycat:MoveBelow(dfire, padding)
    dcopycat:SetX(padding)

    local dredherring = CreateButton(T("puppeteer_puppet_debuff_redherring"), T("puppeteer_puppet_debuff_redherring_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget()
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight)
    dredherring:MoveBelow(dfire, padding)
    dredherring:MoveRightOf(dcopycat, padding)

    local dwanderer = CreateButton(T("puppeteer_puppet_debuff_wanderer"), T("puppeteer_puppet_debuff_wanderer_tip"),
        -- DoClick
        function()
            -- TODO
            DebuffTarget()
        end,
        -- EnablePredicate
        DebuffPredicate,
        dform, buttonWidth, buttonHeight)
    dwanderer:MoveBelow(dfire, padding)
    dwanderer:MoveRightOf(dredherring, padding)

    dsheet:AddSheet(LANG.GetTranslation("puppeteer_puppet_menu_name"), dform, "icon16/television.png", false, false, LANG.GetTranslation("puppeteer_puppet_menu_tip"))
    return true
end)

AddHook("TTTPrepareRound", "Puppeteer_TTTPrepareRound", function()
    ClearCamera()
end)

AddHook("ShouldDrawLocalPlayer", "Puppeteer_ShouldDrawLocalPlayer", function(ply)
    if renderingCamView then return true end
end)

net.Receive("TTTPuppeteerPlayerDeath", function()
    local ply = net.ReadPlayer()
    if IsPlayer(ply) and target == ply then
        client:QueueMessage(MSG_PRINTBOTH, "Your target (\"" .. ply:Nick() .. "\") has died!")
        ClearTarget()
    end
    UpdateTargetsList(ply)
end)

net.Receive("TTTPuppeteerDeath", ClearTarget)
net.Receive("TTTPuppeteerRoleChange", function()
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