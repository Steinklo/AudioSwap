-- Run: lua test_resolve.lua  (stubs the WoW API, checks profile resolution)
local state = { resting = false, group = false, lockdown = false }
local cvars, handler, popups = {}, nil, 0
GetCVar = function(k) return cvars[k] or "1" end
SetCVar = function(k, v) cvars[k] = v end
IsResting = function() return state.resting end
IsInGroup = function() return state.group end
StaticPopup_Show = function() popups = popups + 1 end
C_Timer = { After = function(_, fn) fn() end }
InCombatLockdown = function() return state.lockdown end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
CreateFrame = function()
	return { RegisterEvent = function() end, SetScript = function(_, _, fn) handler = fn end }
end

local ns = { InitUI = function() end }
assert(loadfile("AudioSwap.lua"))("AudioSwap", ns)
handler(nil, "PLAYER_LOGIN")
local db = ns.db
assert(popups == 0) -- not during the loading screen
handler(nil, "PLAYER_ENTERING_WORLD")
handler(nil, "PLAYER_ENTERING_WORLD")
assert(popups == 1) -- welcome once on first run, after entering the world
assert(db.profiles.Default.Sound_MasterVolume and db.profiles.Default.Sound_EnableSoundWhenGameIsInBG)
for _, n in ipairs({ "Combat", "Raid", "Party", "City", "Discord" }) do ns.CreateProfile(n, db.profiles.Default) end
db.profiles.Raid.Sound_MusicVolume = "0.2"
assert(db.profiles.Default.Sound_MusicVolume ~= "0.2") -- profiles are copies, not shared tables
db.slots = { combat = "Combat", group = "Raid", rest = "City" }

assert(ns.Resolve() == "Default")
state.resting = true
assert(ns.Resolve() == "City")
state.group = true
assert(ns.Resolve() == "Raid") -- group outranks rest
handler(nil, "PLAYER_REGEN_DISABLED")
assert(ns.current == "Combat")
ns.MoveCategory(1, 1) -- group above combat
assert(ns.Resolve() == "Raid")
ns.SetManual("Discord")
assert(ns.Resolve() == "Discord") -- manual beats everything
ns.DeleteProfile("Discord")
assert(db.manual == nil and ns.Resolve() == "Raid")

-- Profile management
assert(ns.CreateProfile("Raid", {}) == false) -- duplicate
assert(ns.CreateProfile("rAID", {}) == false) -- duplicate, any case
assert(ns.CreateProfile("", {}) == false)
assert(ns.CreateProfile("Auto", {}) == false) -- reserved by /audioswap auto
assert(ns.DeleteProfile("Default") == false)
ns.DeleteProfile("City")
assert(db.slots.rest == nil) -- slot mapping cleaned up

-- Applying writes CVars; editing only touches the live sound for the active profile
assert(ns.current == "Raid")
ns.SetValue("Raid", "Sound_MasterVolume", "0.3")
assert(cvars.Sound_MasterVolume == "0.3")
ns.SetValue("Party", "Sound_MasterVolume", "0.9")
assert(cvars.Sound_MasterVolume == "0.3")

-- Manual volume tweak survives until the next switch, force re-applies
cvars.Sound_MasterVolume = "0.5"
ns.Update()
assert(cvars.Sound_MasterVolume == "0.5")
ns.Update(true)
assert(cvars.Sound_MasterVolume == "0.3")

-- Switches requested during combat lockdown wait for PLAYER_REGEN_ENABLED
state.lockdown = true
ns.SetManual("Party")
assert(ns.current == "Raid" and cvars.Sound_MasterVolume == "0.3")
state.lockdown = false
handler(nil, "PLAYER_REGEN_ENABLED")
assert(ns.current == "Party" and cvars.Sound_MasterVolume == "0.9")

-- Slash command: case-insensitive names, auto, unknown name
SlashCmdList.AUDIOSWAP("  raid ")
assert(db.manual == "Raid" and ns.current == "Raid")
SlashCmdList.AUDIOSWAP("nope")
assert(db.manual == "Raid")
SlashCmdList.AUDIOSWAP("AUTO")
assert(db.manual == nil)
local opened = false
ns.OpenSettings = function() opened = true end
SlashCmdList.AUDIOSWAP("")
assert(opened)

-- Live preview overrides everything while the panel is open, then hands back
ns.SetPreview("Party")
assert(ns.current == "Party")
ns.SetValue("Party", "Sound_MusicVolume", "0.1")
assert(cvars.Sound_MusicVolume == "0.1") -- edits are heard immediately
ns.SetPreview(nil)
assert(ns.current == "Raid")
ns.SetPreview("Party")
ns.DeleteProfile("Party") -- deleting the previewed profile falls back safely
assert(ns.current == "Raid")
ns.SetPreview(nil)

-- Rename carries mappings, default, manual pick and the playing profile along
ns.SetManual("Raid")
db.default = "Raid"
assert(ns.RenameProfile("Raid", "Default") == false) -- taken
assert(ns.RenameProfile("Raid", "Loud"))
assert(db.profiles.Loud and not db.profiles.Raid)
assert(db.slots.group == "Loud" and db.default == "Loud" and db.manual == "Loud" and ns.current == "Loud")
ns.SetManual(nil)
db.default = "Default"

-- Saved data survives a reload untouched
local saved = AudioSwapDB
handler(nil, "PLAYER_LOGIN")
handler(nil, "PLAYER_ENTERING_WORLD")
assert(ns.db == saved and saved.profiles.Loud and saved.order[1] == "group")
assert(popups == 1) -- no welcome after the first run

-- Every file the TOC loads exists
for line in io.lines("AudioSwap.toc") do
	if line:match("%.lua$") then
		assert(io.open((line:gsub("\\", "/"))), "TOC file missing: " .. line):close()
	end
end
print("ok")
