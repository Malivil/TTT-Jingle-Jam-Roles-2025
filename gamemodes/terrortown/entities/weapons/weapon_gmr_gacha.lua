AddCSLuaFile()

local math = math
local net = net
local pairs = pairs
local table = table

local MathRandom = math.random
local TableHasValue = table.HasValue
local TableInsert = table.insert

if CLIENT then
    SWEP.PrintName          = "Gacha Roller"
    SWEP.Slot               = 8

    SWEP.ViewModelFOV       = 60
    SWEP.DrawCrosshair      = false
    SWEP.ViewModelFlip      = false
else
    util.AddNetworkString("TTTGachaPrizeStart")
end

SWEP.ViewModel              = "models/weapons/c_slam.mdl"
SWEP.WorldModel             = "models/weapons/w_slam.mdl"
SWEP.Weight                 = 2

SWEP.Base                   = "weapon_tttbase"
SWEP.Category               = WEAPON_CATEGORY_ROLE

SWEP.Spawnable              = false
SWEP.AutoSpawnable          = false
SWEP.HoldType               = "slam"
SWEP.Kind                   = WEAPON_ROLE

SWEP.DeploySpeed            = 4
SWEP.AllowDrop              = false
SWEP.NoSights               = true
SWEP.UseHands               = true
SWEP.LimitedStock           = true
SWEP.AmmoEnt                = nil

SWEP.Primary.Delay          = 1
SWEP.Primary.Automatic      = false
SWEP.Primary.Cone           = 0
SWEP.Primary.Ammo           = nil
SWEP.Primary.ClipSize       = -1
SWEP.Primary.ClipMax        = -1
SWEP.Primary.DefaultClip    = 0
SWEP.Primary.Sound          = ""

function SWEP:Initialize()
    self.Primary.Delay = GAMER.Config.Timing.Animations.Reset + 1
    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
    return self.BaseClass.Initialize(self)
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
    return true
end

function SWEP:OnRemove()
    if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
        RunConsoleCommand("lastinv")
    end
end

local function ChooseRandomPrize(ply)
    local chance = MathRandom()
    local targetRarity = GAMER.Rarities.Common
    if chance <= GAMER.Config.Rarities[GAMER.Rarities.Legendary].Chance then
        targetRarity = GAMER.Rarities.Legendary
    elseif chance <= GAMER.Config.Rarities[GAMER.Rarities.Epic].Chance then
        targetRarity = GAMER.Rarities.Epic
    elseif chance <= GAMER.Config.Rarities[GAMER.Rarities.Rare].Chance then
        targetRarity = GAMER.Rarities.Rare
    elseif chance <= GAMER.Config.Rarities[GAMER.Rarities.Uncommon].Chance then
        targetRarity = GAMER.Rarities.Uncommon
    end

    local prizes = {}
    for _, prize in pairs(GAMER.Prizes) do
        if prize.IsUnique and ply.TTTGamerHasUniquePrize then continue end

        local plyPrizes = ply.TTTGamerPrizes or {}
        if TableHasValue(plyPrizes, prize.Id) then continue end
        if not prize:CanStart(ply) then continue end

        if prize.Rarity == targetRarity then
            TableInsert(prizes, prize)
        end
    end

    prizes = {GAMER.Prizes["supergamer"]}

    return prizes[MathRandom(#prizes)]
end

function SWEP:PrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if GetRoundState() ~= ROUND_ACTIVE then return end

    local ammo = self:Clip1()
    if ammo <= 0 then return end

    local owner = self:GetOwner()
    if not IsPlayer(owner) then return end

    if owner:IsRoleAbilityDisabled() then return end

    owner:LagCompensation(true)

    self:SetClip1(ammo - 1)
    self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)

    if SERVER then
        local prize = ChooseRandomPrize(owner)
        net.Start("TTTGamerGachaStart")
            net.WriteString(prize.Id)
        net.Send(owner)

        timer.Create("TTTGmrGachaPrize_" .. owner:SteamID64(), GAMER.Config.Timing.Effect, 1, function()
            if not IsPlayer(owner) then return end
            prize:Start(owner)
            net.Start("TTTGachaPrizeStart")
                net.WriteString(prize.Id)
            net.Send(owner)

            if prize.IsUnique then
                owner.TTTGamerHasUniquePrize = true
            end

            local prizes = owner.TTTGamerPrizes or {}
            TableInsert(prizes, prize.Id)
            owner.TTTGamerPrizes = prizes
        end)

        if ammo == 1 then
            self:Remove()
        end
    end

    owner:LagCompensation(false)
end

function SWEP:DryFire() return false end

if CLIENT then
    net.Receive("TTTGachaPrizeStart", function()
        local prizeId = net.ReadString()
        if GAMER.Prizes[prizeId] then
            GAMER.Prizes[prizeId]:Start(LocalPlayer())
        end
    end)
end