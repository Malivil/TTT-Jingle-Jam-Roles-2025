AddCSLuaFile()

if CLIENT then
    SWEP.PrintName          = "Cheeto Fingers"
    SWEP.Slot               = 8

    SWEP.ViewModelFOV       = 90
    SWEP.DrawCrosshair      = false
    SWEP.ViewModelFlip      = false
end

SWEP.ViewModel 				= "models/weapons/v_knife_other_thefinger.mdl"
SWEP.WorldModel             = ""
SWEP.Weight                 = 2

SWEP.Base                   = "weapon_tttbase"
SWEP.Category               = WEAPON_CATEGORY_ROLE

SWEP.Spawnable              = false
SWEP.AutoSpawnable          = false
SWEP.HoldType               = "normal"
SWEP.Kind                   = WEAPON_ROLE + 1

SWEP.DeploySpeed            = 4
SWEP.AllowDrop              = false
SWEP.NoSights               = true
SWEP.UseHands               = true
SWEP.LimitedStock           = true
SWEP.AmmoEnt                = nil

SWEP.Primary.Delay          = 2
SWEP.Primary.Automatic      = false
SWEP.Primary.Cone           = 0
SWEP.Primary.Ammo           = nil
SWEP.Primary.ClipSize       = -1
SWEP.Primary.ClipMax        = -1
SWEP.Primary.DefaultClip    = 0
SWEP.Primary.Sound          = ""

SWEP.HandColor              = Color(255, 137, 40)

function SWEP:Initialize()
    self:SendWeaponAnim(ACT_VM_IDLE)
    return self.BaseClass.Initialize(self)
end

function SWEP:SetVMColor(col)
    local owner = self:GetOwner()
    if IsValid(owner) then
        local vm = owner:GetViewModel()
        if IsValid(vm) then
            vm:SetColor(col)
        end
    end
end

function SWEP:Deploy()
    self:SendWeaponAnim(ACT_VM_IDLE)
    self:SetVMColor(self.HandColor)
    return true
end

function SWEP:Holster()
    self:SetVMColor(COLOR_WHITE)
    return true
end

function SWEP:OnRemove()
    self:SetVMColor(COLOR_WHITE)
    if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
        RunConsoleCommand("lastinv")
    end
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
    owner:SetAnimation(PLAYER_ATTACK1)

    local spos = owner:GetShootPos()
    local sdest = spos + (owner:GetAimVector() * 70)

    local kmins = Vector(1, 1, 1) * -10
    local kmaxs = Vector(1, 1, 1) * 10

    local tr = util.TraceHull({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})

    -- Hull might hit environment stuff that line does not hit
    if not IsValid(tr.Entity) then
        tr = util.TraceLine({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL})
    end

    local hitEnt = tr.Entity
    if IsValid(hitEnt) then
        self:SendWeaponAnim(ACT_VM_HITCENTER)
        self:SetClip1(ammo - 1)
    else
        self:SendWeaponAnim(ACT_VM_MISSCENTER)
    end

    if SERVER then
        if IsPlayer(hitEnt) then
            -- TODO: Mark someone as tracked (via halo?)
        end

        if self:Clip1() == 0 then
            timer.Simple(self:SequenceDuration(), function()
                if not IsValid(self) then return end
                self:Remove()
            end)
        end
    end

    owner:LagCompensation(false)
end

function SWEP:DryFire() return false end