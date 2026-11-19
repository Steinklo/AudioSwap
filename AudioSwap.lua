local _, ns = ...

-- One row per channel: on/off checkbox + volume slider.
ns.SETTINGS = {
	{ label = "Master", enable = "Sound_EnableAllSound", volume = "Sound_MasterVolume" },
	{ label = "Effects", enable = "Sound_EnableSFX", volume = "Sound_SFXVolume" },
	{ label = "Music", enable = "Sound_EnableMusic", volume = "Sound_MusicVolume" },
	{ label = "Ambience", enable = "Sound_EnableAmbience", volume = "Sound_AmbienceVolume" },
	{ label = "Dialog", enable = "Sound_EnableDialog", volume = "Sound_DialogVolume" },
	{ label = "Sound in background", enable = "Sound_EnableSoundWhenGameIsInBG" },
}

-- Trigger slots per category, most specific first.
ns.CATEGORIES = {
	combat = { label = "Combat", slots = { "combat" }, tip = "Used while you're in combat." },
	group = { label = "Group", slots = { "group" }, tip = "Used in any party or raid, including dungeons and battlegrounds." },
	rest = { label = "Rest", slots = { "rest" }, tip = "Used in rested areas: cities and inns." },
}
ns.SLOT_LABELS = {
	combat = "In combat",
	group = "In group",
	rest = "Rested area",
}

local db
local inCombat = false

local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AudioSwap|r: " .. msg)
end

function ns.Snapshot()
	local p = {}
	for _, s in ipairs(ns.SETTINGS) do
		p[s.enable] = GetCVar(s.enable)
		if s.volume then
			p[s.volume] = GetCVar(s.volume)
		end
	end
	return p
end

function ns.ProfileNames()
	local names = {}
	for name in pairs(db.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- Slots that currently apply in a category, most specific first.
local function activeSlots(cat)
	if cat == "combat" then
		return inCombat and { "combat" } or {}
	elseif cat == "rest" then
		return IsResting() and { "rest" } or {}
	end
	return IsInGroup() and { "group" } or {}
end

function ns.Resolve()
	if db.manual and db.profiles[db.manual] then
		return db.manual
	end
	for _, cat in ipairs(db.order) do
		for _, slot in ipairs(activeSlots(cat)) do
			local name = db.slots[slot]
			if name and db.profiles[name] then
				return name
			end
		end
	end
	return db.default
end

function ns.Update(force)
	-- ponytail: unverified whether Forever blocks sound CVars in combat, so defer; PLAYER_REGEN_ENABLED re-runs this.
	-- PLAYER_REGEN_DISABLED fires before lockdown starts, so the combat profile still applies.
	if InCombatLockdown() then
		return
	end
	local name = db.profiles[ns.preview] and ns.preview or ns.Resolve()
	if force or name ~= ns.current then
		for cvar, value in pairs(db.profiles[name]) do
			SetCVar(cvar, value)
		end
		ns.current = name
	end
	if ns.OnChange then
		ns.OnChange()
	end
end

-- nil = back to automatic.
function ns.SetManual(name)
	db.manual = name
	ns.Update(true)
end

-- Play a profile while it's being edited; nil = back to normal.
function ns.SetPreview(name)
	ns.preview = name
	ns.Update()
end

function ns.SetValue(name, cvar, value)
	db.profiles[name][cvar] = value
	if name == ns.current and not InCombatLockdown() then
		SetCVar(cvar, value)
	end
end

local function findProfile(input)
	input = input:lower()
	for name in pairs(db.profiles) do
		if name:lower() == input then
			return name
		end
	end
end

-- Names are matched case-insensitively by /audioswap, and "auto" is taken.
local function validName(name)
	if name == "" or name:lower() == "auto" or findProfile(name) then
		print("'" .. name .. "' is empty, reserved or already used.")
		return false
	end
	return true
end

function ns.CreateProfile(name, source)
	if not validName(name) then
		return false
	end
	db.profiles[name] = CopyTable(source)
	return true
end

function ns.RenameProfile(old, new)
	if not validName(new) then
		return false
	end
	db.profiles[new], db.profiles[old] = db.profiles[old], nil
	for slot, p in pairs(db.slots) do
		if p == old then
			db.slots[slot] = new
		end
	end
	for _, key in ipairs({ "default", "manual" }) do
		if db[key] == old then
			db[key] = new
		end
	end
	for _, key in ipairs({ "preview", "current" }) do
		if ns[key] == old then
			ns[key] = new
		end
	end
	return true
end

function ns.DeleteProfile(name)
	if name == db.default then
		print("can't delete the default profile.")
		return false
	end
	db.profiles[name] = nil
	for slot, p in pairs(db.slots) do
		if p == name then
			db.slots[slot] = nil
		end
	end
	if db.manual == name then
		db.manual = nil
	end
	ns.Update()
	return true
end

function ns.MoveCategory(i, delta)
	local j = i + delta
	if j < 1 or j > #db.order then
		return
	end
	db.order[i], db.order[j] = db.order[j], db.order[i]
	ns.Update()
end

SLASH_AUDIOSWAP1 = "/audioswap"
SlashCmdList.AUDIOSWAP = function(msg)
	msg = strtrim(msg)
	local name = findProfile(msg)
	if msg == "" then
		ns.OpenSettings()
	elseif msg:lower() == "auto" then
		ns.SetManual(nil)
		print("automatic switching.")
	elseif name then
		ns.SetManual(name)
		print("using " .. name .. " until you pick Auto.")
	else
		print("no profile named '" .. msg .. "'.")
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		AudioSwapDB = AudioSwapDB or {}
		db = AudioSwapDB
		ns.welcome = not db.profiles
		db.profiles = db.profiles or { Default = ns.Snapshot() }
		db.default = db.default or "Default"
		db.order = db.order or { "combat", "group", "rest" }
		db.slots = db.slots or {}
		db.minimap = db.minimap or {}
		ns.db = db
		ns.InitUI()
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_UPDATE_RESTING",
			"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
			f:RegisterEvent(e)
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" and ns.welcome then
		-- Popups shown during the loading screen get closed, so wait until we're in the world.
		ns.welcome = false
		C_Timer.After(2, function()
			print("your current sound is saved as the Default profile. Type /audioswap to set up sound profiles.")
			StaticPopup_Show("AUDIOSWAP_WELCOME")
		end)
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
	end
	ns.Update()
end)
