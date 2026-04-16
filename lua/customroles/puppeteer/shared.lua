
local ROLE = {}

ROLE.nameraw = "puppeteer"
ROLE.name = "Puppeteer"
ROLE.nameplural = "Puppeteers"
ROLE.nameext = "a Puppeteer"
ROLE.nameshort = "pup"

ROLE.desc = [[You are {role}!
TODO]]
ROLE.shortdesc = "TODO"

ROLE.team = ROLE_TEAM_TRAITOR
ROLE.startingcredits = 2

ROLE.convars =
{
    {
        cvar = "ttt_puppeteer_command_fire_duration",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 2
    },
    {
        cvar = "ttt_puppeteer_debuff_pinata_count",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    }
}

ROLE.translations = {
    ["english"] = {
        ["ev_puppeteerdebuffed"] = "{attacker} gave {victim} the '{debuff}' debuff",
        ["puppeteer_hud"] = "{debuff} ({puppeteer} debuff)",
        ["puppeteer_puppet_target_you"] = "you",
        ["puppeteer_puppet_menu_name"] = "Puppet",
        ["puppeteer_puppet_menu_tip"] = "Manipulate a chosen player's actions",
        ["puppeteer_puppet_target_label"] = "Control Target",
        ["puppeteer_puppet_target_placeholder"] = "- Select Target Player -",
        ["puppeteer_puppet_target_window"] = "View of {target}",
        ["puppeteer_puppet_actions"] = "Actions",
        ["puppeteer_puppet_fire_weapon"] = "Fire Weapon for {time}s",
        ["puppeteer_puppet_debuffs"] = "Debuffs",
        ["puppeteer_puppet_debuffs_desc"] = "Costs 1 credit per use",
        ["puppeteer_puppet_debuff_0"] = "Piñata",
        ["puppeteer_puppet_debuff_0_tip"] = "When the target dies, they drop {num} random {traitor} items",
        ["puppeteer_puppet_debuff_1"] = "Spoilsport",
        ["puppeteer_puppet_debuff_1_tip"] = "TODO",
        ["puppeteer_puppet_debuff_2"] = "Copycat",
        ["puppeteer_puppet_debuff_2_tip"] = "Target becomes the role of the next player they kill",
        ["puppeteer_puppet_debuff_3"] = "Red Herring",
        ["puppeteer_puppet_debuff_3_tip"] = "Disguises the target as {atraitor} in testers and when their corpse is searched",
        ["puppeteer_puppet_debuff_4"] = "Wanderer",
        ["puppeteer_puppet_debuff_4_tip"] = "Forces the target to move to specific locations around the map or they die"
    }
}

RegisterRole(ROLE)

-------------------
-- ROLE FEATURES --
-------------------

PUPPETEER_DEBUFF_TYPE_PINATA = 0
PUPPETEER_DEBUFF_TYPE_SPOILSPORT = 1
PUPPETEER_DEBUFF_TYPE_COPYCAT = 2
PUPPETEER_DEBUFF_TYPE_REDHERRING = 3
PUPPETEER_DEBUFF_TYPE_WANDERER = 4

------------------
-- ROLE CONVARS --
------------------

CreateConVar("ttt_puppeteer_command_fire_duration", 2, FCVAR_REPLICATED, "How long (in seconds) the target's weapon should be fired for when the Puppeteer commands it", 0.25, 10)
CreateConVar("ttt_puppeteer_debuff_pinata_count", 3, FCVAR_REPLICATED, "How many shop items a player with the Piñata debuff will drop when they are killed", 1, 10)