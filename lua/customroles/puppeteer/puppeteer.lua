AddCSLuaFile()

local hook = hook
local player = player

local AddHook = hook.Add
local PlayerIterator = player.Iterator

util.AddNetworkString("TTT_PuppeteerPlayerDeath")
util.AddNetworkString("TTT_PuppeteerDeath")
util.AddNetworkString("TTT_PuppeteerRoleChange")
util.AddNetworkString("TTT_PuppeteerSetDebuff")
util.AddNetworkString("TTT_PuppeteerClearDebuff")
util.AddNetworkString("TTT_PuppeteerDebuffed")

-------------------
-- ROLE FEATURES --
-------------------

local function ValidTarget(role)
    return DETECTIVE_ROLES[role] or TRAITOR_ROLES[role] or role == ROLE_GLITCH or JESTER_ROLES[role]
end

-- Update the client if a viable target or a puppeteer has died
AddHook("PostPlayerDeath", "Puppeteer_PostPlayerDeath", function(ply)
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
    -- If their viability hasn't changed then the client doesn't need to update
    if ValidTarget(oldRole) == ValidTarget(newRole) then return end

    for _, p in PlayerIterator() do
        if not p:IsActivePuppeteer() then continue end

        net.Start("TTT_PuppeteerRoleChange")
            net.WritePlayer(ply)
        net.Send(p)
    end
end)

net.Receive("TTT_PuppeteerSetDebuff", function(len, ply)
    local target = net.ReadPlayer()
    local debuff = net.ReadString()
    if not IsPlayer(ply) or not ply:IsActivePuppeteer() then return end
    if not IsPlayer(target) or not target:Alive() or target:IsSpec() then return end

    -- TODO: Notify the target

    target:SetProperty("TTTPuppeteerDebuffed", true)
    net.Start("TTT_PuppeteerDebuffed")
        net.WriteString(ply:Nick())
        net.WriteString(target:Nick())
        net.WriteString(debuff)
    net.Broadcast()
end)

net.Receive("TTT_PuppeteerClearDebuff", function(len, ply)
    local target = net.ReadPlayer()
    if not IsPlayer(ply) or not ply:IsActivePuppeteer() then return end
    if not IsPlayer(target) or not target:Alive() or target:IsSpec() then return end

    target:ClearProperty("TTTPuppeteerDebuffed")
end)

AddHook("TTTPrepareRound", "Puppeteer_TTTPrepareRound", function()
    for _, v in PlayerIterator() do
        v:ClearProperty("TTTPuppeteerDebuffed")
    end
end)

------------
-- EVENTS --
------------

AddHook("Initialize", "Puppeteer_Initialize", function()
    EVENT_PUPPETEERDEBUFFED = GenerateNewEventID(ROLE_PUPPETEER)
end)
