local hook = hook
local player = player
local util = util

local AddHook = hook.Add
local PlayerIterator = player.Iterator

util.AddNetworkString("TTTGamerGachaStart")

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
    elseif isequip == EQUIP_GAMER_MTDEW then
        -- TODO: 20% speed increase and triple jump
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
    elseif isequip == EQUIP_GAMER_SPAGHETTI then
        -- TODO: Provides 5% health regen per second (unsure if permanent or not)
    elseif isequip == EQUIP_GAMER_MILK then
        -- TODO: ??
    end
end)

-------------
-- CLEANUP --
-------------

local function Cleanup()
    for _, p in PlayerIterator() do
        timer.Remove("TTTGmrGachaPrize_" .. p:SteamID64())
        p:ClearProperty("TTTGamerHasUniquePrize", p)
        p:ClearProperty("TTTGamerCheetoMarked")
    end
end

AddHook("TTTPrepareRound", "Gamer_TTTPrepareRound", Cleanup)
AddHook("TTTEndRound", "Gamer_TTTEndRound", Cleanup)