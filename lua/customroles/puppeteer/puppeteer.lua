AddCSLuaFile()

local hook = hook
local player = player

local AddHook = hook.Add
local PlayerIterator = player.Iterator

util.AddNetworkString("TTTPuppeteerPlayerDeath")
util.AddNetworkString("TTTPuppeteerDeath")
util.AddNetworkString("TTTPuppeteerRoleChange")
util.AddNetworkString("TTTPuppeteerSetDebuff")
util.AddNetworkString("TTTPuppeteerClearDebuff")

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

            net.Start("TTTPuppeteerPlayerDeath")
                net.WritePlayer(ply)
            net.Send(p)
        end
    end

    if ply:IsPuppeteer() then
        net.Start("TTTPuppeteerDeath")
        net.Send(ply)
    end
end)

-- Update the client if a player has been changed to or from a viable target role
AddHook("TTTPlayerRoleChanged", "Puppeteer_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
    -- If their viability hasn't changed then the client doesn't need to update
    if ValidTarget(oldRole) == ValidTarget(newRole) then return end

    for _, p in PlayerIterator() do
        if not p:IsActivePuppeteer() then continue end

        net.Start("TTTPuppeteerRoleChange")
            net.WritePlayer(ply)
        net.Send(p)
    end
end)

net.Receive("TTTPuppeteerSetDebuff", function(len, ply)
    local target = net.ReadPlayer()
    if not IsPlayer(ply) or not ply:IsActivePuppeteer() then return end
    if not IsPlayer(target) or not target:Alive() or target:IsSpec() then return end

    target:SetProperty("TTTPuppeteerDebuffed", true)
end)

net.Receive("TTTPuppeteerClearDebuff", function(len, ply)
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