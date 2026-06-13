local PRIZE = {
    Id = "recoil_rare",
    Name = "gamer_prize_recoil_rare_name",
    Description = "gamer_prize_recoil_desc",
    DescriptionParams = { amt = "50" },
    Rarity = GAMER.Rarities.Rare,
    Icon = Material("vgui/ttt/gamer/prizes/recoil.png"),
    SillyName = "gamer_prize_mouse_rare",
    SillyIcon = Material("vgui/ttt/gamer/prizes/mouse_rare.png")
}

function PRIZE:Start(ply)
    if SERVER then
        hook.Add("WeaponEquip", "Gamer_WeaponEquip_Rare_" .. ply:SteamID64(), function(weap, p)
            if not IsPlayer(ply) then return end
            if p ~= ply then return end
            GAMER.AdjustWeaponRecoil(weap, 0.5, p)
        end)
    end
    for _, weap in ipairs(ply:GetWeapons()) do
        GAMER.AdjustWeaponRecoil(weap, 0.5)
    end
end

function PRIZE:End(ply)
    if SERVER then
        hook.Remove("WeaponEquip", "Gamer_WeaponEquip_Rare_" .. ply:SteamID64())
    end
    for _, weap in ipairs(ply:GetWeapons()) do
        GAMER.ResetWeaponRecoil(weap)
    end
end

GAMER.AddPrize(PRIZE)