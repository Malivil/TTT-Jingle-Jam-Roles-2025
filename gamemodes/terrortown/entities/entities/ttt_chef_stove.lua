if SERVER then
    AddCSLuaFile()
end

if CLIENT then
    local hint_params = {usekey = Key("+use", "USE")}

    ENT.TargetIDHint = function(stove)
        local client = LocalPlayer()
        if not IsPlayer(client) then return end

        local name
        if not IsValid(stove) or stove:GetPlacer() ~= client then
            name = LANG.GetTranslation("chf_stove_name")
        else
            name = LANG.GetParamTranslation("chf_stove_name_health", { current = stove:Health(), max = stove:GetMaxHealth() })
        end

        return {
            name = name,
            hint = "chf_stove_hint",
            fmt  = function(ent, txt)
                if not IsValid(stove) then return nil end

                local hint = txt
                if cooking then
                    -- TODO: Time progress + status (cooking || done || burnt)
                    if ent:GetPlacer() == client and (done or burnt) then
                        -- TODO: Press "E" to retrieve food
                    end
                elseif ent:GetPlacer() == client then
                    -- TODO: Press "E" to start cooking
                end

                return nil--LANG.GetParamTranslation(hint, hint_params)
            end
        }
    end
    ENT.AutomaticFrameAdvance = true
end

ENT.Type = "anim"

ENT.CanUseKey = true
ENT.StoveModel = "models/props_forest/stove01.mdl"

AccessorFuncDT(ENT, "FoodType", "FoodType")
AccessorFuncDT(ENT, "StartTime", "StartTime")
AccessorFuncDT(ENT, "Placer", "Placer")

local food_model =
{
    [CHEF_FOOD_TYPE_BURGER] = "models/food/burger.mdl",
    [CHEF_FOOD_TYPE_HOTDOG] = "models/food/hotdog.mdl",
    [CHEF_FOOD_TYPE_FISH] = "models/props/de_inferno/goldfish.mdl"
}

function ENT:SetupDataTables()
   self:DTVar("Int", 0, "FoodType")
   self:DTVar("Int", 1, "StartTime")
   self:DTVar("Entity", 0, "Placer")
end

function ENT:Initialize()
    if not SERVER then return end

    self:SetModel(self.StoveModel)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_BBOX)
    self:DrawShadow(true)

    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    self:WeldToGround(true)
    self:SetUseType(CONTINUOUS_USE)
end

if SERVER then
    local damage_own_stove = CreateConVar("ttt_chef_damage_own_stove", "0", FCVAR_NONE, "Whether a stove's owner can damage it", 0, 1)
    local warn_damage = CreateConVar("ttt_chef_warn_damage", "1", FCVAR_NONE, "Whether to warn a stove's owner is warned when it is damaged", 0, 1)
    local warn_destroy = CreateConVar("ttt_chef_warn_destroy", "1", FCVAR_NONE, "Whether to warn a stove's owner is warned when it is destroyed", 0, 1)

    function ENT:OnTakeDamage(dmginfo)
        local att = dmginfo:GetAttacker()
        local placer = self:GetPlacer()
        if not IsPlayer(placer) then return end

        if att:ShouldActLikeJester() then return end
        if att == placer and not damage_own_stove:GetBool() then return end

        self:SetHealth(self:Health() - dmginfo:GetDamage())

        if IsPlayer(att) then
            DamageLog(Format("DMG: \t %s [%s] damaged stove %s [%s] for %d dmg", att:Nick(), ROLE_STRINGS[att:GetRole()], placer:Nick(), ROLE_STRINGS[placer:GetRole()], dmginfo:GetDamage()))
        end

        if self:Health() <= 0 then
            self:DestroyStove()
            if warn_destroy:GetBool() then
                placer:QueueMessage(MSG_PRINTBOTH, "Your Stove has been destroyed!")
            end
        elseif warn_damage:GetBool() then
            LANG.Msg(placer, "chf_stove_damaged")
        end
    end

    function ENT:Use(activator)
        if not IsPlayer(activator) then return end

        local placer = self:GetPlacer()
        if not IsPlayer(placer) then return end

        -- TODO: Stop cooking, if the food is at least done
    end

    function ENT:DestroyStove()
        self:WeldToGround(false)

        local effect = EffectData()
        effect:SetOrigin(self:GetPos())
        util.Effect("cball_explode", effect)
        self:Remove()
    end

    -- Copied from C4
    function ENT:WeldToGround(state)
        if state then
           -- getgroundentity does not work for non-players
           -- so sweep ent downward to find what we're lying on
           local ignore = player.GetAll()
           table.insert(ignore, self)

           local tr = util.TraceEntity({ start = self:GetPos(), endpos = self:GetPos() - Vector(0, 0, 16), filter = ignore, mask = MASK_SOLID }, self)

           -- Start by increasing weight/making uncarryable
           local phys = self:GetPhysicsObject()
           if IsValid(phys) then
              -- Could just use a pickup flag for this. However, then it's easier to
              -- push it around.
              self.OrigMass = phys:GetMass()
              phys:SetMass(150)
           end

           if tr.Hit and (IsValid(tr.Entity) or tr.HitWorld) then
              -- "Attach" to a brush if possible
              if IsValid(phys) and tr.HitWorld then
                 phys:EnableMotion(false)
              end

              -- Else weld to objects we cannot pick up
              local entphys = tr.Entity:GetPhysicsObject()
              if IsValid(entphys) and entphys:GetMass() > CARRY_WEIGHT_LIMIT then
                 constraint.Weld(self, tr.Entity, 0, 0, 0, true)
              end

              -- Worst case, we are still uncarryable
           end
        else
           constraint.RemoveConstraints(self, "Weld")
           local phys = self:GetPhysicsObject()
           if IsValid(phys) then
              phys:EnableMotion(true)
              phys:SetMass(self.OrigMass or 10)
           end
        end
     end
end