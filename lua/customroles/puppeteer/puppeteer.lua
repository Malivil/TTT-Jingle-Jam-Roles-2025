AddCSLuaFile()

local hook = hook
local player = player

local AddHook = hook.Add
local PlayerIterator = player.Iterator

util.AddNetworkString("TTTPuppeteerPlayerDeath")
util.AddNetworkString("TTTPuppeteerDeath")

-------------------
-- ROLE FEATURES --
-------------------

AddHook("PostPlayerDeath", "Puppeteer_PostPlayerDeath", function(ply)
    for _, p in PlayerIterator() do
        if not p:IsActivePuppeteer() then continue end

        net.Start("TTTPuppeteerPlayerDeath")
            net.WritePlayer(ply)
        net.Send(p)
    end

    if ply:IsPuppeteer() then
        net.Start("TTTPuppeteerDeath")
        net.Send(ply)
    end
end)