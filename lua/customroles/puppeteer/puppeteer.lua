AddCSLuaFile()

local ents = ents
local hook = hook
local math = math
local net = net
local pairs = pairs
local player = player
local table = table
local timer = timer
local weapons = weapons

local AddHook = hook.Add
local CreateEntity = ents.Create
local MathRandom = math.random
local PlayerIterator = player.Iterator
local RunHook = hook.Run
local TableInsert = table.insert
local TableRemove = table.remove

util.AddNetworkString("TTT_PuppeteerPlayerDeath")
util.AddNetworkString("TTT_PuppeteerDeath")
util.AddNetworkString("TTT_PuppeteerRoleChange")
util.AddNetworkString("TTT_PuppeteerSetDebuff")
util.AddNetworkString("TTT_PuppeteerDebuffed")
util.AddNetworkString("TTT_PuppeteerFireWeapon")
util.AddNetworkString("TTT_PuppeteerFireWeaponEnd")

------------------
-- ROLE CONVARS --
------------------

local puppeteer_command_fire_duration = GetConVar("ttt_puppeteer_command_fire_duration")
local puppeteer_debuff_pinata_count = GetConVar("ttt_puppeteer_debuff_pinata_count")
local puppeteer_debuff_wanderer_delay = GetConVar("ttt_puppeteer_debuff_wanderer_delay")
local puppeteer_debuff_wanderer_timer = GetConVar("ttt_puppeteer_debuff_wanderer_timer")
local puppeteer_debuff_wanderer_distance = GetConVar("ttt_puppeteer_debuff_wanderer_distance")

-------------------
-- ROLE FEATURES --
-------------------

local function ClearState(ply)
    ply:ClearProperty("TTTPuppeteerDebuffed")
    ply:ClearProperty("TTTPuppeteerDebuff")
    ply:ClearProperty("TTTPuppeteerRedHerring")
    ply:ClearProperty("TTTPuppeteerWandererTarget", ply)
    ply:ClearProperty("TTTPuppeteerWandererEnd", ply)
    timer.Remove("Puppeteer_PinataWeaponDrop_" .. ply:SteamID64())
    timer.Remove("Puppeteer_Wanderer_" .. ply:SteamID64())
    timer.Remove("Puppeteer_FireWeapon_" .. ply:SteamID64())
end

local function ValidTarget(role)
    return not DETECTIVE_ROLES[role] and not TRAITOR_ROLES[role] and not role == ROLE_GLITCH and not JESTER_ROLES[role]
end

local StartPinataDrop
AddHook("PostPlayerDeath", "Puppeteer_PostPlayerDeath", function(ply)
    if not IsPlayer(ply) then return end

    -- Update the client if a viable target or a puppeteer has died
    if ValidTarget(ply:GetRole()) then
        net.Start("TTT_PuppeteerPlayerDeath")
            net.WritePlayer(ply)
        net.Send(GetRoleFilter(ROLE_PUPPETEER, true))
    end
    if ply:IsPuppeteer() then
        net.Start("TTT_PuppeteerDeath")
        net.Send(ply)
    end

    local debuff = ply.TTTPuppeteerDebuff
    ClearState(ply)

    -- Start Piñata logic before clearing state
    if debuff == PUPPETEER_DEBUFF_TYPE_PINATA then
        StartPinataDrop(ply)
    end
end)

-- Update the client if a player has been changed to or from a viable target role
AddHook("TTTPlayerRoleChanged", "Puppeteer_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
    if not IsPlayer(ply) then return end

    -- If their viability hasn't changed then the client doesn't need to update
    local isValidTarget = ValidTarget(newRole)
    if ValidTarget(oldRole) == isValidTarget then return end

    -- If they were a valid target but they aren't now and they are debuffed, clear their debuff
    if not isValidTarget and ply.TTTPuppeteerDebuffed then
        ply:ClearProperty("TTTPuppeteerDebuffed")
        ply:ClearProperty("TTTPuppeteerDebuff")
    end

    net.Start("TTT_PuppeteerRoleChange")
        net.WritePlayer(ply)
    net.Send(GetRoleFilter(ROLE_PUPPETEER, true))
end)

local StartWandererDebuff
net.Receive("TTT_PuppeteerSetDebuff", function(_, ply)
    local target = net.ReadPlayer()
    local debuff = net.ReadUInt(3)

    if not IsPlayer(ply) or not ply:IsActivePuppeteer() then return end
    if not IsPlayer(target) or not target:Alive() or target:IsSpec() then return end
    if ply:GetCredits() < 1 then return end

    ply:SubtractCredits(1)
    target:SetProperty("TTTPuppeteerDebuffed", true)
    target:SetProperty("TTTPuppeteerDebuff", debuff)
    net.Start("TTT_PuppeteerDebuffed")
        net.WritePlayer(ply)
        net.WritePlayer(target)
        net.WriteUInt(debuff, 3)
    net.Broadcast()

    StartWandererDebuff(ply, target)
end)

-----------------
-- FIRE WEAPON --
-----------------

net.Receive("TTT_PuppeteerFireWeapon", function(len, ply)
    local target = net.ReadPlayer()

    if not IsPlayer(ply) or not ply:IsActivePuppeteer() then return end
    if not IsPlayer(target) or not target:Alive() or target:IsSpec() then return end

    net.Start("TTT_PuppeteerFireWeapon")
        net.WritePlayer(target)
    net.Send(GetRoleFilter(ROLE_PUPPETEER, true))

    local wep = target.GetActiveWeapon and target:GetActiveWeapon() or nil
    if not IsValid(wep) then return end
    if not wep.Primary or not wep.Primary.Delay then return end

    target:QueueMessage(MSG_PRINTBOTH, string.Capitalize(ROLE_STRINGS_EXT[ROLE_PUPPETEER]) .. " is forcing you to use your weapon!")

    local dur = puppeteer_command_fire_duration:GetInt()
    local repeats = math.floor(dur/wep.Primary.Delay) + 1
    local timerId = "Puppeteer_FireWeapon_" .. ply:SteamID64()
    timer.Create(timerId, wep.Primary.Delay, repeats, function()
        if timer.RepsLeft(timerId) == 0 and IsPlayer(target) then
            net.Start("TTT_PuppeteerFireWeaponEnd")
                net.WritePlayer(target)
            net.Send(GetRoleFilter(ROLE_PUPPETEER, true))
        end

        if not IsValid(wep) then return end

        if wep:Clip1() ~= 0 then
            wep:PrimaryAttack()
            wep:SetNextPrimaryFire(CurTime() + wep.Primary.Delay)
        end
    end)
end)

-------------
-- DEBUFFS --
-------------

-- Piñata --

local function DropWeapon(wep, source_pos)
    local pos = source_pos + Vector(0, 0, 25)
    local ent = CreateEntity(wep)
    ent:SetPos(pos)
    ent:Spawn()

    local phys = ent:GetPhysicsObject()
    if phys:IsValid() then phys:ApplyForceCenter(Vector(math.Rand(-100, 100), math.Rand(-100, 100), 300) * phys:GetMass()) end
end

StartPinataDrop = function(ply)
    local lootTable = {}
    timer.Create("Puppeteer_PinataWeaponDrop_" .. ply:SteamID64(), 0.05, puppeteer_debuff_pinata_count:GetInt(), function()
        if #lootTable == 0 then -- Rebuild the loot table if we run out
            for _, v in ipairs(weapons.GetList()) do
                if not v then continue end

                -- Only allow weapons that can be bought, can be dropped, and don't spawn on their own
                -- Specifically check AllowDrop for `false` because weapons in this list don't have the base table
                -- applied and the base table has AllowDrop defaulting to `true`
                if v.AutoSpawnable or v.AllowDrop == false then continue end
                if not v.CanBuy or #v.CanBuy == 0 then continue end

                -- Only allow weapons that a traitor role can buy
                local hasTraitor = false
                for _, r in pairs(v.CanBuy) do
                    if TRAITOR_ROLES[r] then
                        hasTraitor = true
                        break
                    end
                end
                if not hasTraitor then continue end

                TableInsert(lootTable, WEPS.GetClass(v))
            end
        end

        local ragdoll = ply.server_ragdoll or ply:GetRagdollEntity()
        local idx = MathRandom(1, #lootTable)
        local wep = lootTable[idx]
        TableRemove(lootTable, idx)

        DropWeapon(wep, ragdoll:GetPos())
    end)
end

-- Spoilsport --

-- Do this in "DoPlayerDeath" so the Vindicator logic in "PlayerDeath" happens after
AddHook("DoPlayerDeath", "Puppeteer_Spoilsport_DoPlayerDeath", function(ply, attacker, dmg)
    if not IsPlayer(ply) then return end
    if ply.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_SPOILSPORT then return end

    if not IsPlayer(attacker) then return end

    ply:QueueMessage(MSG_PRINTTALK, "You've decided to spoil " .. attacker:Nick() .. "'s fun by coming back as " .. ROLE_STRINGS_EXT[ROLE_VINDICATOR])
    ply:SetRole(ROLE_VINDICATOR)
    ply:StripRoleWeapons()
    RunHook("PlayerLoadout", ply)
    SendFullStateUpdate()
end)

-- Copycat --

AddHook("PlayerDeath", "Puppeteer_Copycat_PlayerDeath", function(victim, inflictor, attacker)
    if not IsPlayer(attacker) then return end
    if attacker.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_COPYCAT then return end

    local traitors = player.GetTeamPlayers(ROLE_TEAM_TRAITOR, true, true)
    if #traitors > 0 then
        attacker:QueueMessage(MSG_PRINTBOTH, "You've taken " .. victim:Nick() .. "'s role and become " .. ROLE_STRINGS_EXT[victim:GetRole()])
        attacker:SetRole(victim:GetRole())
        attacker:StripRoleWeapons()
        RunHook("PlayerLoadout", attacker)
        victim:MoveRoleState(attacker)
        SendFullStateUpdate()

        attacker:ClearProperty("TTTPuppeteerDebuffed")
        attacker:ClearProperty("TTTPuppeteerDebuff")
    end
end)

-- Red Herring --

AddHook("TTTOnCorpseCreated", "Puppeteer_RedHerring_TTTOnCorpseCreated", function(rag, ply)
    if not IsPlayer(ply) then return end
    if ply.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_REDHERRING then return end
    if rag.puppet_role then return end

    ply:SetProperty("TTTPuppeteerRedHerring", true)
    rag.puppet_role = rag.was_role
    if rag.was_role == ROLE_INNOCENT then
        rag.was_role = ROLE_PUPPETEER
    else
        rag.was_role = ROLE_TRAITOR
    end
end)

AddHook("TTTPlayerPassesTraitorCheck", "Puppeteer_RedHerring_TTTPlayerPassesTraitorCheck", function(ply, ent)
    if not IsPlayer(ply) then return end
    if ply.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_REDHERRING then return end

    if ent:GetClass() == "ttt_traitor_check" then
        return true
    end

    -- The other traitor checks have a Role property
    -- If they are checking for traitors, the Red Herring passes the check
    return ent.Role == ROLE_TRAITOR
end)

AddHook("PlayerSpawn", "Puppeteer_RedHerring_PlayerSpawn", function(ply)
    if not IsPlayer(ply) then return end
    if not ply.TTTPuppeteerRedHerring then return end
    ply:ClearProperty("TTTPuppeteerRedHerring")
end)

-- Wanderer --

local function GetWandererPosition()
    local spawns = GetSpawnEnts(true, false)
    for _, e in ents.Iterator() do
        if IsValid(e:GetParent()) then continue end
        if e:WaterLevel() ~= 0 then continue end
        local entity_class = e:GetClass()
        if string.StartsWith(entity_class, "weapon_") or string.StartsWith(entity_class, "item_") then
            TableInsert(spawns, e)
        end
    end
    local spawn = spawns[MathRandom(#spawns)]
    return spawn:GetPos()
end

StartWandererDebuff = function(ply, target)
    local delay = puppeteer_debuff_wanderer_delay:GetInt()
    local time = puppeteer_debuff_wanderer_timer:GetInt()
    local distance = puppeteer_debuff_wanderer_distance:GetFloat() * UNITS_PER_METER
    local distSqr = distance * distance
    local timerId = "Puppeteer_Wanderer_" .. target:SteamID64()
    local phase = true
    timer.Create(timerId, delay, 0, function()
        if not IsPlayer(target) or not target:IsActive() or target.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_WANDERER then
            timer.Remove(timerId)
            return
        end

        -- First phase is the delay
        if phase then
            local pos = GetWandererPosition()
            target:SetProperty("TTTPuppeteerWandererTarget", pos, target)
            local endTime = CurTime() + time
            target:SetProperty("TTTPuppeteerWandererEnd", endTime, target)
            target:QueueMessage(MSG_PRINTBOTH, "You have " .. time .. " second(s) to get to the target location!")
            timer.Adjust(timerId, time)
        -- Second phase is the hunt
        else
            -- If the player is close enough to the target then they are safe. Start the delay over again
            if target:GetPos():DistToSqr(target.TTTPuppeteerWandererTarget) <= distSqr then
                target:QueueMessage(MSG_PRINTBOTH, "You are safe... for now")
                timer.Adjust(timerId, delay)
            -- Otherwise, they die
            else
                local dmginfo = DamageInfo()
                dmginfo:SetDamage(1000)
                dmginfo:SetAttacker(ply or game.GetWorld())
                dmginfo:SetInflictor(ply or game.GetWorld())
                dmginfo:SetDamageType(DMG_SLASH)
                target:TakeDamageInfo(dmginfo)
                timer.Remove(timerId)
            end

            target:ClearProperty("TTTPuppeteerWandererTarget", target)
            target:ClearProperty("TTTPuppeteerWandererEnd", target)
        end
        phase = not phase
    end)
end

------------
-- EVENTS --
------------

AddHook("Initialize", "Puppeteer_Initialize", function()
    EVENT_PUPPETEERDEBUFFED = GenerateNewEventID(ROLE_PUPPETEER)
end)

-------------
-- CLEANUP --
-------------

AddHook("TTTPrepareRound", "Puppeteer_TTTPrepareRound", function()
    for _, v in PlayerIterator() do
        v:ClearProperty("TTTPuppeteerDebuffed")
        v:ClearProperty("TTTPuppeteerDebuff")
        v:ClearProperty("TTTPuppeteerRedHerring")
        v:ClearProperty("TTTPuppeteerWandererTarget", v)
        v:ClearProperty("TTTPuppeteerWandererEnd", v)
        timer.Remove("Puppeteer_PinataWeaponDrop_" .. v:SteamID64())
        timer.Remove("Puppeteer_Wanderer_" .. v:SteamID64())
        timer.Remove("Puppeteer_FireWeapon_" .. v:SteamID64())
    end
end)