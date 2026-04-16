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
local TableInsert = table.insert
local TableRemove = table.remove

util.AddNetworkString("TTT_PuppeteerPlayerDeath")
util.AddNetworkString("TTT_PuppeteerDeath")
util.AddNetworkString("TTT_PuppeteerRoleChange")
util.AddNetworkString("TTT_PuppeteerSetDebuff")
util.AddNetworkString("TTT_PuppeteerDebuffed")
util.AddNetworkString("TTT_PuppeteerDebuffRedHerring")

------------------
-- ROLE CONVARS --
------------------

local puppeteer_debuff_pinata_count = GetConVar("ttt_puppeteer_debuff_pinata_count")

-------------------
-- ROLE FEATURES --
-------------------

local function ValidTarget(role)
    return DETECTIVE_ROLES[role] or TRAITOR_ROLES[role] or role == ROLE_GLITCH or JESTER_ROLES[role]
end

-- Update the client if a viable target or a puppeteer has died
AddHook("PostPlayerDeath", "Puppeteer_PostPlayerDeath", function(ply)
    if not IsPlayer(ply) then return end

    if ValidTarget(ply:GetRole()) then
        for _, p in PlayerIterator() do
            if not p:IsActivePuppeteer() then continue end

            net.Start("TTT_PuppeteerPlayerDeath")
                net.WritePlayer(ply)
            net.Send(p)
        end
    end

    if ply:IsPuppeteer() then
        net.Start("TTT_PuppeteerDeath")
        net.Send(ply)
    end
end)

-- Update the client if a player has been changed to or from a viable target role
AddHook("TTTPlayerRoleChanged", "Puppeteer_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
    if not IsPlayer(ply) then return end

    -- If their viability hasn't changed then the client doesn't need to update
    if ValidTarget(oldRole) == ValidTarget(newRole) then return end

    for _, p in PlayerIterator() do
        if not p:IsActivePuppeteer() then continue end

        net.Start("TTT_PuppeteerRoleChange")
            net.WritePlayer(ply)
        net.Send(p)
    end
end)

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

AddHook("PostPlayerDeath", "Puppeteer_Pinata_PostPlayerDeath", function(ply)
    if not IsPlayer(ply) then return end
    if ply.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_PINATA then return end

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
end)

-- Red Herring --

AddHook("TTTCanIdentifyCorpse", "Puppeteer_RedHerring_TTTCanIdentifyCorpse", function(ply, rag, was_traitor)
    if not IsPlayer(ply) then return end
    if ply.TTTPuppeteerDebuff ~= PUPPETEER_DEBUFF_TYPE_REDHERRING then return end

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
        timer.Remove("Puppeteer_PinataWeaponDrop_" .. v:SteamID64())
    end
end)