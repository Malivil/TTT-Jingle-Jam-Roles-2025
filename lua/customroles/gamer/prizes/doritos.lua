local PRIZE = {
    Id = "doritos",
    Name = "gamer_prize_doritos_name",
    Description = "gamer_prize_doritos_desc",
    Rarity = GAMER.Rarities.Legendary,
    Icon = Material("vgui/ttt/gamer/doritos.png")
}

function PRIZE:Start(ply)
    print("Doritos!", ply)
end

GAMER.AddPrize(PRIZE)