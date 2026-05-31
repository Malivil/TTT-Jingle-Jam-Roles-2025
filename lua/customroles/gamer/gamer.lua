local cvars = cvars
local hook = hook
local math = math
local player = player
local timer = timer
local util = util

local AddHook = hook.Add
local MathMin = math.min
local PlayerIterator = player.Iterator

util.AddNetworkString("TTTGamerGachaStart")

------------------
-- ROLE CONVARS --
------------------

local gamer_spaghetti_amount = CreateConVar("ttt_gamer_spaghetti_amount", "5", FCVAR_REPLICATED, "The amount of health a player should regain per interval after they each spaghetti", 1, 25)
local gamer_spaghetti_interval = CreateConVar("ttt_gamer_spaghetti_interval", "5", FCVAR_REPLICATED, "How often a player who eats spaghetti should regain health", 1, 60)

----------------
-- ROLE LOGIC --
----------------

AddHook("TTTOrderedEquipment", "Gamer_TTTOrderedEquipment", function(ply, id, isequip)
    if not isequip then return end

    if isequip == EQUIP_GAMER_DORITOS then
        -- If the player doesn't have the gacha roller already, give it to them
        local gacha
        if ply:HasWeapon("weapon_gmr_gacha") then
            gacha = ply:GetWeapon("weapon_gmr_gacha")
        else
            gacha = ply:Give("weapon_gmr_gacha")
        end

        -- And give it some ammo
        if IsValid(gacha) then
            gacha:SetClip1(math.max(0, gacha:Clip1()) + 2)
        end
        ply:EmitSound("gamer/doritos.mp3", 100, 100, 1, CHAN_ITEM)
    elseif isequip == EQUIP_GAMER_MTDEW then
        if ply.SetMaxJumpLevel then
            ply:SetMaxJumpLevel(ply:GetMaxJumpLevel() + 1)
        else
            p:SetJumpPower(320)
        end
        ply:EmitSound("gamer/mtdew.mp3", 100, 100, 1, CHAN_ITEM)
    elseif isequip == EQUIP_GAMER_CHEETOS then
        -- Heal the player to max
        local hp = ply:Health()
        local max = ply:GetMaxHealth()
        if hp < max then
            ply:SetHealth(max)
        end

        -- If the player doesn't have the cheeto fingers already, give it to them
        local fingers
        if ply:HasWeapon("weapon_gmr_cheeto_fingers") then
            fingers = ply:GetWeapon("weapon_gmr_cheeto_fingers")
        else
            fingers = ply:Give("weapon_gmr_cheeto_fingers")
        end

        -- And give it some ammo
        if IsValid(fingers) then
            fingers:SetClip1(math.max(0, fingers:Clip1()) + 1)
        end
        ply:EmitSound("gamer/cheetos.mp3", 100, 100, 1, CHAN_ITEM)
    elseif isequip == EQUIP_GAMER_SPAGHETTI then
        ply:EmitSound("gamer/spaghetti.mp3", 100, 100, 1, CHAN_ITEM)
    elseif isequip == EQUIP_GAMER_MILK then
        -- TODO: ??
        ply:EmitSound("gamer/milk.mp3", 100, 100, 1, CHAN_ITEM)
    end
end)

AddHook("TTTPlayerAliveThink", "Gamer_Spaghetti_TTTPlayerAliveThink", function(ply)
    if not IsPlayer(ply) then return end
    if not ply:HasEquipmentItem(EQUIP_GAMER_SPAGHETTI) then return end

    local lastHeal = ply.TTTGamerSpaghettiHealTime or 0
    local curTime = CurTime()
    if lastHeal + gamer_spaghetti_interval:GetInt() > curTime then return end

    ply.TTTGamerSpaghettiHealTime = curTime

    local hp = ply:Health()
    local newHp = MathMin(ply:GetMaxHealth(), hp + gamer_spaghetti_amount:GetInt())
    if hp >= newHp then return end

    ply:SetHealth(newHp)
end)

-------------
-- CLEANUP --
-------------

local function Cleanup()
    local jumps = cvars.Number("multijump_default_jumps", 1)
    for _, p in PlayerIterator() do
        timer.Remove("TTTGmrGachaPrize_" .. p:SteamID64())
        p.TTTGamerSpaghettiHealTime = nil
        p:ClearProperty("TTTGamerHasUniquePrize", p)
        p:ClearProperty("TTTGamerCheetoMarked")
        if p.SetMaxJumpLevel then
            p:SetMaxJumpLevel(jumps)
        else
            p:SetJumpPower(160)
        end
    end
end

AddHook("TTTPrepareRound", "Gamer_TTTPrepareRound", Cleanup)
AddHook("TTTEndRound", "Gamer_TTTEndRound", Cleanup)