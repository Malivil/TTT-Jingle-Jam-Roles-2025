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

local function UpdateButtonState(disabled)
    for _, btn in pairs(buttons) do
        local enabled = not disabled and (not btn.EnablePredicate or btn:EnablePredicate())
        btn:SetEnabled(enabled)
    end
end

local function ClearCamera()
	if cameraFrame then
		cameraFrame:Remove()
		cameraFrame = nil
	end
end

local function ClearTarget()
    target = nil
    UpdateButtonState(true)
    ClearCamera()
end

local function CreateCamera()
	cameraFrame = vgui.Create("DFrame")
	cameraFrame:SetSize(ScrW() / 5, ScrH() / 5)
	cameraFrame:SetPos(0, 0)
	cameraFrame:SetTitle(LANG.GetParamTranslation("puppeteer_puppet_target_window", { target = target:Nick() }))
	cameraFrame:SetDraggable(true)
	cameraFrame:SetSizable(true)
	function cameraFrame:Paint()
	    local x, y, w, h = cameraFrame:GetBounds()
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

    local dtarget = vgui.Create("DComboBox", dform)
    dtarget:SetValue(T("puppeteer_puppet_target_placeholder"))
    dtarget:SetEnabled(true)
    for _, p in PlayerIterator() do
        if not IsPlayer(p) then continue end
        if not p:Alive() or p:IsSpec() then continue end
        if p == client then continue end
        if p:IsDetectiveTeam() then continue end
        if p:IsTraitorTeam() or p:IsGlitch() then continue end
        if p:IsJesterTeam() then continue end
        dtarget:AddChoice(p:Nick(), p:SteamID64())
    end
    function dtarget:OnSelect(idx, val, data)
        local tgt = player.GetBySteamID64(data)
        local disabled = (not data or #data == 0) and IsPlayer(tgt)
        UpdateButtonState(disabled)

        if disabled then
            target = nil
            ClearCamera()
        else
            target = tgt
            CreateCamera()
        end
    end
    dform:AddItem(dtarget)

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
    div:MoveBelow(dtarget)
    div:Dock(FILL)
    div:SetPaintBackground(true)
    div:SetBackgroundColor(COLOR_LGRAY)
    dform:AddItem(div)

    local dfire = vgui.Create("DButton", dform)
    local fire_duration = puppeteer_command_fire_duration:GetFloat()
    dfire:SetText(PT("puppeteer_puppet_fire_weapon", { time = fire_duration }))
    -- TODO: Position
    dfire:MoveBelow(div)
    -- TODO: Size
    dfire.EnablePredicate = function()
        -- TODO: Cooldown
    end
    dfire.DoClick = function()
        -- TODO
    end
    dfire:SetEnabled(false)
    TableInsert(buttons, dfire)
    dform:AddItem(dfire)

    -- TODO: Debuff buttons

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
        ClearTarget()
    end
end)

net.Receive("TTTPuppeteerDeath", function()
    ClearTarget()
end)