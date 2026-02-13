local hook = hook
local ipairs = ipairs
local player = player
local weapons = weapons
local util = util

local AddHook = hook.Add
local PlayerIterator = player.Iterator

local ROLE = {}

ROLE.nameraw = "thief"
ROLE.name = "Thief"
ROLE.nameplural = "Thieves"
ROLE.nameext = "a Thief"
ROLE.nameshort = "thf"

ROLE.desc = [[You are {role}!
]]
ROLE.shortdesc = ""

ROLE.team = ROLE_TEAM_INDEPENDENT

ROLE.convars =
{
    {
        cvar = "ttt_thief_is_innocent",
        type = ROLE_CONVAR_TYPE_BOOL
    },
    {
        cvar = "ttt_thief_is_traitor",
        type = ROLE_CONVAR_TYPE_BOOL
    }
}

ROLE.translations =
{
    ["english"] =
    {
        ["win_thief"] = "The {role} has stolen its way to victory!",
        ["ev_win_thief"] = "The {role} has stolen its way to victory!",
        ["ev_thiefstolen"] = "{thief} stole {item} from {victim}"
    }
}

------------------
-- ROLE CONVARS --
------------------

local thief_is_innocent = CreateConVar("ttt_thief_is_innocent", "0", FCVAR_REPLICATED, "Whether the Thief should be on the innocent team", 0, 1)
local thief_is_traitor = CreateConVar("ttt_thief_is_traitor", "0", FCVAR_REPLICATED, "Whether the Thief should be on the traitor team", 0, 1)
local thief_steal_cost = CreateConVar("ttt_thief_steal_cost", "0", FCVAR_REPLICATED, "Whether stealing a weapon from a player requires a credit. Enables credit looting for innocent and independent Thieves on new round", 0, 1)

-------------------
-- ROLE FEATURES --
-------------------

AddHook("TTTUpdateRoleState", "Thief_TTTUpdateRoleState", function()
    local is_innocent = thief_is_innocent:GetBool()
    -- Thieves cannot be both Innocents and Traitors so don't make them Traitors if they are already Innocents
    local is_traitor = not is_innocent and thief_is_traitor:GetBool()
    INNOCENT_ROLES[ROLE_THIEF] = is_innocent
    TRAITOR_ROLES[ROLE_THIEF] = is_traitor
    INDEPENDENT_ROLES[ROLE_THIEF] = not is_innocent and not is_traitor

    -- Only let thieves loot credits if they have something that costs credits
    -- NOTE: If they are on the traitor team, this is ignored so we don't have to even bother checking
    CAN_LOOT_CREDITS_ROLES[ROLE_THIEF] = thief_steal_cost:GetInt() > 0
end)

THIEF_STEAL_MODE_PROXIMITY = 0
THIEF_STEAL_MODE_TOOLS = 1

if SERVER then
    AddCSLuaFile()

    util.AddNetworkString("TTT_ThiefItemStolen")

    ------------------
    -- ROLE CONVARS --
    ------------------

    local thief_steal_mode = CreateConVar("ttt_thief_steal_mode", "0", FCVAR_NONE, "How stealing a weapon from a player works. 0 - Steal automatically when in proximity. 1 - Steal using they Thieves Tools", 0, 1)
    CreateConVar("ttt_thief_steal_cooldown", "30", FCVAR_NONE, "How long (in seconds) after the Thief steals something that they can try to steal another thing")
    CreateConVar("ttt_thief_steal_proximity_time", "15", FCVAR_NONE, "How long (in seconds) it takes the Thief to steal something from a target. Only used when \"ttt_thief_steal_mode 0\" is set")
    CreateConVar("ttt_thief_steal_proximity_float_time", "3", FCVAR_NONE, "The amount of time (in seconds) it takes for the Thief to lose their target after getting out of range. Only used when \"ttt_thief_steal_mode 0\" is set", 0, 60)
    CreateConVar("ttt_thief_steal_proximity_require_los", "1", FCVAR_NONE, "Whether the Thief requires line-of-sight to steal something. Only used when \"ttt_thief_steal_mode 0\" is set", 0, 1)
    CreateConVar("ttt_thief_steal_proximity_distance", "5", FCVAR_NONE, "How close (in meters) the Thief needs to be to their target to start stealing. Only used when \"ttt_thief_steal_mode 0\" is set")
    --distance = thief_steal_proximity_distance:GetFloat() * UNITS_PER_METER

    -------------------
    -- ROLE FEATURES --
    -------------------

    -- TODO: Steal a weapon somehow, set the property on the weapon so the thief can get it, start the cooldown, and send the net method

    AddHook("TTTPlayerAliveThink", "Thief_TTTPlayerAliveThink_Steal", function(ply)
        if thief_steal_mode:GetInt() ~= THIEF_STEAL_MODE_PROXIMITY then return end
        if not ply:IsThief() then return end
        if ply:IsRoleAbilityDisabled() then return end


    end)

    AddHook("Initialize", "Thief_Initialize", function()
        WIN_THIEF = GenerateNewWinID(ROLE_THIEF)
        EVENT_THIEFSTOLEN = GenerateNewEventID(ROLE_THIEF)
    end)

    -- Thief can only use the weapons they steal
    ROLE.onroleassigned = function(ply)
        -- Use a slight delay to make sure nothing else is changing this player's role first
        timer.Simple(0.25, function()
            if not IsPlayer(ply) then return end
            ply:StripWeapons()
            ply:Give("weapon_ttt_unarmed")
        end)
    end

    AddHook("PlayerCanPickupWeapon", "Thief_PlayerCanPickupWeapon", function(ply, wep)
        if not IsPlayer(ply) then return end
        if not ply:IsActiveThief() then return end
        if not IsValid(wep) then return end

        local wepClass = WEPS.GetClass(wep)
        if wepClass ~= "weapon_ttt_unarmed" and not wep.TTTThiefStolen then
            return false
        end
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("TTTCheckForWin", "Thief_TTTCheckForWin", function()
        if not INDEPENDENT_ROLES[ROLE_THIEF] then return end

        local thief_alive = false
        local other_alive = false
        for _, v in PlayerIterator() do
            if v:IsActive() then
                if v:IsThief() then
                    thief_alive = true
                elseif not v:ShouldActLikeJester() and not ROLE_HAS_PASSIVE_WIN[v:GetRole()] then
                    other_alive = true
                end
            end
        end

        if thief_alive and not other_alive then
            return WIN_THIEF
        end
    end)

    AddHook("TTTPrintResultMessage", "Thief_TTTPrintResultMessage", function(type)
        if type == WIN_THIEF then
            LANG.Msg("win_thief", { role = ROLE_STRINGS[ROLE_THIEF] })
            ServerLog("Result: " .. ROLE_STRINGS[ROLE_THIEF] .. " wins.\n")
            return true
        end
    end)
end

if CLIENT then
    -------------------
    -- ROLE FEATURES --
    -------------------

    -- TODO: Show cooldown on the UI
    -- TODO: Show proximity steal progress on the UI

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("TTTSyncWinIDs", "Thief_TTTSyncWinIDs", function()
        WIN_THIEF = WINS_BY_ROLE[ROLE_THIEF]
    end)

    AddHook("TTTScoringWinTitle", "Thief_TTTScoringWinTitle", function(wintype, wintitles, title, secondary_win_role)
        if wintype == WIN_THIEF then
            return { txt = "hilite_win_role_singular", params = { role = utf8.upper(ROLE_STRINGS[ROLE_THIEF]) }, c = ROLE_COLORS[ROLE_THIEF] }
        end
    end)

    ------------
    -- EVENTS --
    ------------

    local function GetWeaponName(item)
        local wep = util.WeaponForClass(item) or weapons.Get(item)
        if wep and (wep.PrintName or wep.GetPrintName) then
            return LANG.TryTranslation(wep.PrintName or wep:GetPrintName())
        end

        -- Sometimes the direct methods don't seem to work, so we'll do a loop if they fail
        for _, v in ipairs(weapons.GetList()) do
            if item == WEPS.GetClass(v) then
                return LANG.TryTranslation(v.GetPrintName and v:GetPrintName() or v.PrintName or item)
            end
        end

        return item
    end

    AddHook("TTTEventFinishText", "Thief_TTTEventFinishText", function(e)
        if e.win == WIN_THIEF then
            return LANG.GetParamTranslation("ev_win_thief", { role = string.lower(ROLE_STRINGS[ROLE_THIEF]) })
        end
    end)

    AddHook("TTTEventFinishIconText", "Thief_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_THIEF then
            return win_string, ROLE_STRINGS[ROLE_THIEF]
        end
    end)

    AddHook("TTTSyncEventIDs", "Thief_TTTSyncEventIDs", function()
        EVENT_THIEFSTOLEN = EVENTS_BY_ROLE[ROLE_THIEF]
        local swap_icon = Material("icon16/lock_open.png")
        local Event = CLSCORE.DeclareEventDisplay
        local PT = LANG.GetParamTranslation
        Event(EVENT_THIEFSTOLEN, {
            text = function(e)
                return PT("ev_thiefstolen", {thief = e.thf, victim = e.vic, item = e.item})
            end,
            icon = function(e)
                return swap_icon, "Item stolen"
            end})
    end)

    net.Receive("TTT_ThiefItemStolen", function(len)
        local thief = net.ReadString()
        local victim = net.ReadString()
        local item = net.ReadString()
        CLSCORE:AddEvent({
            id = EVENT_THIEFSTOLEN,
            thf = thief,
            vic = victim,
            item = GetWeaponName(item)
        })
    end)

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Thief_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_THIEF then
            local roleColor = GetRoleTeamColor(ROLE_TEAM_INDEPENDENT)
            local html = "The " .. ROLE_STRINGS[ROLE_THIEF] .. " is an <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>independent</span> role whose goal is to be the last player standing."

            -- TODO

            return html
        end
    end)
end

RegisterRole(ROLE)