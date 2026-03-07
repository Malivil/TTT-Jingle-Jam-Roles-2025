local hook = hook
local math = math
local string = string
local table = table

local AddHook = hook.Add
local MathRad = math.rad
local MathSin = math.sin
local MathCos = math.cos
local MathMax = math.max
local StringSub = string.sub
local StringFormat = string.format
local TableInsert = table.insert
local Utf8Upper = utf8.upper

local ROLE = {}

ROLE.nameraw = "button"
ROLE.name = "Button"
ROLE.nameplural = "Buttons"
ROLE.nameext = "a Button"
ROLE.nameshort = "btn"

ROLE.desc = [[You are {role}! Get traitors to push
you enough times to win, But don't let the timer
run out without an innocent turning you back or the
traitors will win instead!]]
ROLE.shortdesc = "Turns into a button that wants to be pressed to win, but if no one stops the countdown traitors win instead."

ROLE.team = ROLE_TEAM_JESTER

ROLE.convars =
{
    {
        cvar = "ttt_button_presses_to_win",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_button_reset_mode",
        type = ROLE_CONVAR_TYPE_DROPDOWN,
        choices = {"Everyone", "Not the activator", "Not traitors"},
        isNumeric = true,
        numericOffset = 0
    },
    {
        cvar = "ttt_button_traitor_activate_only",
        type = ROLE_CONVAR_TYPE_BOOL
    },
    {
        cvar = "ttt_button_countdown_length",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 1
    },
    {
        cvar = "ttt_button_countdown_pause",
        type = ROLE_CONVAR_TYPE_BOOL
    }
}

BUTTON_RESET_BLOCK_NONE = 0
BUTTON_RESET_BLOCK_PRESSER = 1
BUTTON_RESET_BLOCK_TRAITORS = 2

------------------
-- ROLE CONVARS --
------------------

local button_presses_to_win = CreateConVar("ttt_button_presses_to_win", "3", FCVAR_REPLICATED, "How many times the Button needs to be activated to win.", 1, 10)
local button_reset_mode = CreateConVar("ttt_button_reset_mode", "1", FCVAR_REPLICATED, "Who is allowed to reset the Button's countdown. 0 - Everyone. 1 - Not the activator. 2 - Not traitors.", 0, 2)
local button_traitor_activate_only = CreateConVar("ttt_button_traitor_activate_only", "1", FCVAR_REPLICATED, "Whether only traitors are allowed to activate the Button and start the countdown.", 0, 1)
local button_countdown_length = CreateConVar("ttt_button_countdown_length", "10", FCVAR_REPLICATED, "How long the Button's countdown lasts before traitors win.", 1, 60)
local button_countdown_pause = CreateConVar("ttt_button_countdown_pause", "0", FCVAR_REPLICATED, "If the Button's countdown should pause instead of resetting.", 0, 1)

if SERVER then
    AddCSLuaFile()

    -------------------
    -- ROLE FEATURES --
    -------------------



    -------------
    -- CLEANUP --
    -------------


end

-- TODO: Button model (models/maxofs2d/button_05.mdl)
-- TODO: Button stand texture (dev/graygrid)

if CLIENT then
    ---------
    -- HUD --
    ---------

    local function DrawSevenSegmentDigit(digit, x, y, w, l, m)
        -- Segment A (Top)
        if digit ~= "1" and digit ~= "4" then
            surface.DrawPoly({
                {x = x + w/2 + m,       y = y + w/2},
                {x = x + w + m,         y = y},
                {x = x + l + m,         y = y},
                {x = x + w/2 + l + m,   y = y + w/2},
                {x = x + l + m,         y = y + w},
                {x = x + w + m,         y = y + w}
            })
        end

        -- Segment B (Top Right)
        if digit ~= "5" and digit ~= "6" then
            surface.DrawPoly({
                {x = x + w/2 + l + 2*m, y = y + w/2 + m},
                {x = x + w + l + 2*m,   y = y + w + m},
                {x = x + w + l + 2*m,   y = y + l + m},
                {x = x + w/2 + l + 2*m, y = y + w/2 + l + m},
                {x = x + l + 2*m,       y = y + l + m},
                {x = x + l + 2*m,       y = y + w + m}
            })
        end

        -- Segment C (Bottom Right)
        if digit ~= "2" then
            surface.DrawPoly({
                {x = x + w/2 + l + 2*m, y = y + w/2 + l + 3*m},
                {x = x + w + l + 2*m,   y = y + w + l + 3*m},
                {x = x + w + l + 2*m,   y = y + 2*l + 3*m},
                {x = x + w/2 + l + 2*m, y = y + w/2 + 2*l + 3*m},
                {x = x + l + 2*m,       y = y + 2*l + 3*m},
                {x = x + l + 2*m,       y = y + w + l + 3*m}
            })
        end

        -- Segment D (Bottom)
        if digit ~= "1" and digit ~= "4" and digit ~= "7" then
            surface.DrawPoly({
                {x = x + w/2 + m,       y = y + w/2 + 2*l + 4*m},
                {x = x + w + m,         y = y + 2*l + 4*m},
                {x = x + l + m,         y = y + 2*l + 4*m},
                {x = x + w/2 + l + m,   y = y + w/2 + 2*l + 4*m},
                {x = x + l + m,         y = y + w + 2*l + 4*m},
                {x = x + w + m,         y = y + w + 2*l + 4*m}
            })
        end

        -- Segment E (Bottom Left)
        if digit == "2" or digit == "6" or digit == "8" or digit == "0" then
            surface.DrawPoly({
                {x = x + w/2,           y = y + w/2 + l + 3*m},
                {x = x + w,             y = y + w + l + 3*m},
                {x = x + w,             y = y + 2*l + 3*m},
                {x = x + w/2,           y = y + w/2 + 2*l + 3*m},
                {x = x,                 y = y + 2*l + 3*m},
                {x = x,                 y = y + w + l + 3*m}
            })
        end

        -- Segment F (Top Left)
        if digit ~= "1" and digit ~= "2" and digit ~= "3" and digit ~= "7" then
            surface.DrawPoly({
                {x = x + w/2,           y = y + w/2 + m},
                {x = x + w,             y = y + w + m},
                {x = x + w,             y = y + l + m},
                {x = x + w/2,           y = y + w/2 + l + m},
                {x = x,                 y = y + l + m},
                {x = x,                 y = y + w + m}
            })
        end

        -- Segment G (Center)
        if digit ~= "1" and digit ~= "7" and digit ~= "0" then
            surface.DrawPoly({
                {x = x + w/2 + m,       y = y + w/2 + l + 2*m},
                {x = x + w + m,         y = y + l + 2*m},
                {x = x + l + m,         y = y + l + 2*m},
                {x = x + w/2 + l + m,   y = y + w/2 + l + 2*m},
                {x = x + l + m,         y = y + w + l + 2*m},
                {x = x + w + m,         y = y + w + l + 2*m}
            })
        end
    end

    local function DrawCircle(x, y, r)
        x = x + r
        y = y + r
        local circle = {}

        for i = 0, 12 do
            local a = MathRad((i/10) * -360)
            TableInsert(circle, {x = x + MathSin(a) * r, y = y + MathCos(a) * r})
        end

        surface.DrawPoly(circle)
    end

    local function DrawSevenSegmentNumber(num, x, y, w, l, m)
        local display = StringFormat("%05.2f", num)
        for i = 1, #display do
            local digit = StringSub(display, i,i)
            if digit == "." then
                DrawCircle(x - w/2, y + 2*l + 4*m, w/2)
                x = x + w
            else
                DrawSevenSegmentDigit(digit, x, y, w, l, m)
                x = x + 2*w + l + 2*m
            end
        end

    end

    AddHook("HUDPaint", "Button_HUDPaint", function()
        local remaining = MathMax(0, GetGlobalFloat("ttt_round_end", 0) - CurTime())
        surface.SetDrawColor(255, 0, 0, 192)
        DrawSevenSegmentNumber(remaining, ScrW() / 2, ScrH() / 2, 8, 28, 2)
    end)

    ---------------
    -- TARGET ID --
    ---------------

    AddHook("TTTTargetIDPlayerRoleIcon", "Button_TTTTargetIDPlayerRoleIcon", function(ply, cli, role, noz, color_role, hideBeggar, showJester, hideBodysnatcher)
        if GetRoundState() < ROUND_ACTIVE then return end
        if cli:IsTraitorTeam() and ply:IsButton() then
            return ROLE_BUTTON, false, ROLE_BUTTON
        end
    end)

    AddHook("TTTTargetIDPlayerRing", "Button_TTTTargetIDPlayerRing", function(ent, cli, ring_visible)
        if GetRoundState() < ROUND_ACTIVE then return end
        if not IsPlayer(ent) then return end

        if cli:IsTraitorTeam() and ent:IsButton() then
            return true, ROLE_COLORS_RADAR[ROLE_BUTTON]
        end
    end)

    AddHook("TTTTargetIDPlayerText", "Button_TTTTargetIDPlayerText", function(ent, cli, text, col, secondary_text)
        if GetRoundState() < ROUND_ACTIVE then return end
        if not IsPlayer(ent) then return end

        if cli:IsTraitorTeam() and ent:IsButton() then
            return Utf8Upper(ROLE_STRINGS[ROLE_BUTTON]), ROLE_COLORS_RADAR[ROLE_BUTTON]
        end
    end)

    ROLE.istargetidoverridden = function(ply, target)
        if GetRoundState() < ROUND_ACTIVE then return end
        if not IsPlayer(target) then return end

        local visible = ply:IsTraitorTeam() and target:IsButton()
        ------ icon,    ring,    text
        return visible, visible, visible
    end

    ----------------
    -- SCOREBOARD --
    ----------------

    AddHook("TTTScoreboardPlayerRole", "Button_TTTScoreboardPlayerRole", function(ply, cli, color, roleFileName)
        if GetRoundState() < ROUND_ACTIVE then return end
        if (cli:IsTraitorTeam() and ply:IsButton()) then
            return ROLE_COLORS_SCOREBOARD[ROLE_BUTTON], ROLE_STRINGS_SHORT[ROLE_BUTTON]
        end
    end)

    ROLE.isscoreboardinfooverridden = function(ply, target)
        if GetRoundState() < ROUND_ACTIVE then return end
        if not IsPlayer(target) then return end

        local visible = ply:IsTraitorTeam() and target:IsButton()
        ------ name,  role
        return false, visible
    end

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Button_TTTTutorialRoleText", function(role, titleLabel)
        -- TODO: Add tutorial
        if role == ROLE_BUTTON then
            local roleColor = ROLE_COLORS[ROLE_BUTTON]
            local html = "The " .. ROLE_STRINGS[ROLE_BUTTON] .. " is a <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>jester role</span>"

            return html
        end
    end)
end

RegisterRole(ROLE)