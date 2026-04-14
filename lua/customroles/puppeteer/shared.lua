
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
    }
}

ROLE.translations = {
    ["english"] = {
        ["ev_puppeteerdebuffed"] = "{attacker} gave {victim} the '{debuff}' debuff",
        ["puppeteer_puppet_menu_name"] = "Puppet",
        ["puppeteer_puppet_menu_tip"] = "Manipulate a chosen player's actions",
        ["puppeteer_puppet_target_label"] = "Control Target",
        ["puppeteer_puppet_target_placeholder"] = "- Select Target Player -",
        ["puppeteer_puppet_target_window"] = "View of {target}",
        ["puppeteer_puppet_fire_weapon"] = "Fire Weapon for {time}s",
        ["puppeteer_puppet_debuff_pinata"] = "Piñata",
        ["puppeteer_puppet_debuff_pinata_tip"] = "When the target dies, they drop {num} random {traitor} items",
        ["puppeteer_puppet_debuff_spoilsport"] = "Spoilsport",
        ["puppeteer_puppet_debuff_spoilsport_tip"] = "TODO",
        ["puppeteer_puppet_debuff_copycat"] = "Copycat",
        ["puppeteer_puppet_debuff_copycat_tip"] = "Target becomes the role of the next player they kill",
        ["puppeteer_puppet_debuff_redherring"] = "Red Herring",
        ["puppeteer_puppet_debuff_redherring_tip"] = "TODO",
        ["puppeteer_puppet_debuff_wanderer"] = "Wanderer",
        ["puppeteer_puppet_debuff_wanderer_tip"] = "Forces the target to move to specific locations around the map or they die"
    }
}

RegisterRole(ROLE)

------------------
-- ROLE CONVARS --
------------------

CreateConVar("ttt_puppeteer_command_fire_duration", 2, FCVAR_REPLICATED, "How long (in seconds) the target's weapon should be fired for when the Puppeteer commands it", 0.25, 10)