local _, ns = ...

local ROW = 28
local LABEL_W = 130
local RIGHT_X = 380
local editing -- profile shown (and playing) in the editor
local refreshing = false
local category
local widgets = { dropdowns = {}, sliders = {}, checks = {}, sections = {} }

function ns.OpenSettings()
	Settings.OpenToCategory(category:GetID())
end

local function label(parent, text, x, y, font)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(text)
	return fs
end

local function button(parent, text, width, x, y, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function arrow(parent, dir, x, y, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(24, 24)
	b:SetPoint("TOPLEFT", x, y)
	b:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. dir .. "-Up")
	b:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. dir .. "-Down")
	b:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. dir .. "-Disabled")
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	b:SetScript("OnClick", onClick)
	return b
end

local function tooltip(frame, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, nil, nil, nil, nil, true)
	end)
	frame:SetScript("OnLeave", GameTooltip_Hide)
end

local function profileDropdown(parent, x, y, width, get, set, allowNone)
	local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	dd:SetWidth(width)
	dd:SetPoint("TOPLEFT", x, y + 4)
	dd:SetupMenu(function(_, root)
		if allowNone then
			root:CreateRadio("(none)", function() return get() == nil end, function() set(nil) end)
		end
		for _, name in ipairs(ns.ProfileNames()) do
			root:CreateRadio(name, function() return get() == name end, function() set(name) end)
		end
	end)
	table.insert(widgets.dropdowns, dd)
	return dd
end

local function edit(name)
	editing = name
	ns.SetPreview(name)
	ns.Refresh()
end

-- Popups: name prompt (hasEditBox) or yes/no; the profile being acted on is passed as data.
local function popup(key, text, hasEditBox, onAccept)
	StaticPopupDialogs["AUDIOSWAP_" .. key] = {
		text = text,
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = hasEditBox,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		OnAccept = function(dialog, data)
			onAccept(data, hasEditBox and strtrim(dialog:GetEditBox():GetText()))
		end,
		EditBoxOnEnterPressed = function(editBox, data)
			onAccept(data, strtrim(editBox:GetText()))
			StaticPopup_Hide("AUDIOSWAP_" .. key)
		end,
		EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	}
end

StaticPopupDialogs.AUDIOSWAP_WELCOME = {
	text = "Welcome to AudioSwap!\n\nYour current sound is saved as the Default sound profile. Set up more profiles now?",
	button1 = "Open settings",
	button2 = "Later",
	OnAccept = function() ns.OpenSettings() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

popup("NEW", "New sound profile name (starts as a copy of Default):", true, function(_, name)
	if ns.CreateProfile(name, ns.db.profiles[ns.db.default]) then edit(name) end
end)
popup("DUPLICATE", "Copy %s as:", true, function(source, name)
	if ns.CreateProfile(name, ns.db.profiles[source]) then edit(name) end
end)
popup("RENAME", "Rename %s to:", true, function(old, name)
	if ns.RenameProfile(old, name) then edit(name) end
end)
popup("DELETE", "Delete sound profile %s?", false, function(name)
	if ns.DeleteProfile(name) then edit(ns.db.default) end
end)

local function showPopup(key)
	StaticPopup_Show("AUDIOSWAP_" .. key, editing, nil, editing)
end

-- Category sections stack in priority order, so their position on screen is the ranking.
local function layoutSections()
	local y = -110
	for i, cat in ipairs(ns.db.order) do
		local s = widgets.sections[cat]
		s:SetPoint("TOPLEFT", RIGHT_X, y)
		s.up:SetEnabled(i > 1)
		s.down:SetEnabled(i < #ns.db.order)
		y = y - s:GetHeight() - 10
	end
end

function ns.Refresh()
	if not ns.db.profiles[editing] then
		editing = ns.db.default
	end
	refreshing = true
	for _, dd in ipairs(widgets.dropdowns) do
		dd:GenerateMenu()
	end
	local p = ns.db.profiles[editing]
	for cvar, s in pairs(widgets.sliders) do
		s:SetValue(tonumber(p[cvar]) or 0)
	end
	for cvar, cb in pairs(widgets.checks) do
		cb:SetChecked(p[cvar] == "1")
	end
	layoutSections()
	refreshing = false
end

local function buildPanel()
	local panel = CreateFrame("Frame")
	panel:SetScript("OnShow", function() edit(editing or ns.db.default) end)
	panel:SetScript("OnHide", function() ns.SetPreview(nil) end)
	local db = ns.db

	-- Left column: profile editor.
	local x, y = 16, -16
	label(panel, "Sound profiles", x, y, "GameFontNormalLarge")
	y = y - 32
	profileDropdown(panel, x, y, 220, function() return editing end, edit)
	label(panel, "Shared by all your characters. The selected one plays\nwhile this panel is open, so you hear your changes.",
		x, y - 26, "GameFontDisableSmall")
	y = y - 62
	for i, b in ipairs({
		{ "New", "NEW", "Create a sound profile, starting as a copy of Default." },
		{ "Duplicate", "DUPLICATE", "Copy the selected sound profile." },
		{ "Rename", "RENAME", "Rename the selected sound profile. Its situations follow it." },
		{ "Delete", "DELETE", "Delete the selected sound profile. Default can't be deleted." },
	}) do
		tooltip(button(panel, b[1], 84, x + (i - 1) * 88, y, function() showPopup(b[2]) end), b[3])
	end
	y = y - ROW - 12

	for _, s in ipairs(ns.SETTINGS) do
		local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
		cb:SetPoint("TOPLEFT", x - 4, y + 5)
		cb:SetScript("OnClick", function(self)
			ns.SetValue(editing, s.enable, self:GetChecked() and "1" or "0")
		end)
		widgets.checks[s.enable] = cb
		label(panel, s.label, x + 24, y)
		if s.volume then
			local slider = CreateFrame("Slider", nil, panel, "MinimalSliderWithSteppersTemplate")
			slider:SetSize(170, 20)
			slider:SetPoint("TOPLEFT", x + LABEL_W, y + 4)
			slider:Init(0, 0, 1, 100, {
				[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
					MinimalSliderWithSteppersMixin.Label.Right,
					function(v) return math.floor(v * 100 + 0.5) .. "%" end),
			})
			slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
				if not refreshing then
					ns.SetValue(editing, s.volume, tostring(v))
				end
			end, slider)
			widgets.sliders[s.volume] = slider
		end
		y = y - ROW
	end

	-- Right column: automatic switching.
	x, y = RIGHT_X, -16
	label(panel, "Automatic switching", x, y, "GameFontNormalLarge")
	y = y - 32
	label(panel, "When nothing matches", x, y)
	profileDropdown(panel, x + LABEL_W + 20, y, 140, function() return db.default end, function(name)
		db.default = name
		ns.Update()
		ns.Refresh()
	end)
	label(panel, "Higher sections win. Use the arrows to reorder.", x, y - 26, "GameFontDisableSmall")

	for cat, info in pairs(ns.CATEGORIES) do
		local s = CreateFrame("Frame", nil, panel)
		s:SetSize(290, 24 + #info.slots * ROW)
		local header = label(s, info.label, 0, -4, "GameFontNormal")
		tooltip(s, info.tip)
		s.up = arrow(s, "Up", 0, 0, function() ns.MoveCategory(tIndexOf(db.order, cat), -1); ns.Refresh() end)
		s.up:ClearAllPoints()
		s.up:SetPoint("LEFT", header, "RIGHT", 6, 0)
		s.down = arrow(s, "Down", 0, 0, function() ns.MoveCategory(tIndexOf(db.order, cat), 1); ns.Refresh() end)
		s.down:ClearAllPoints()
		s.down:SetPoint("LEFT", s.up, "RIGHT", 0, 0)
		for i, slot in ipairs(info.slots) do
			local sy = -i * ROW
			label(s, ns.SLOT_LABELS[slot], 10, sy)
			profileDropdown(s, LABEL_W + 20, sy, 140, function() return db.slots[slot] end, function(name)
				db.slots[slot] = name
				ns.Update()
				ns.Refresh()
			end, true)
		end
		widgets.sections[cat] = s
	end

	label(panel, "How it works", 16, -350, "GameFontNormal")
	local help = label(panel, table.concat({
		"1. Click New to make a sound profile, e.g. \"Discord\" with low volume.",
		"2. Pick it any time from the minimap icon or /audioswap discord.",
		"    It stays until you choose Auto.",
		"3. Or let AudioSwap switch for you: on the right, choose a profile",
		"    for combat, groups or rested areas. Anything else uses Default.",
	}, "\n"), 16, -372, "GameFontHighlightSmall")
	help:SetJustifyH("LEFT")
	help:SetSpacing(3)

	category = Settings.RegisterCanvasLayoutCategory(panel, "AudioSwap")
	Settings.RegisterAddOnCategory(category)
	return panel
end

local function buildMinimap()
	local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("AudioSwap", {
		type = "data source",
		text = "AudioSwap",
		icon = "Interface\\Icons\\INV_Misc_Bell_01",
		OnClick = function(self, mouse)
			if mouse == "RightButton" then
				ns.OpenSettings()
				return
			end
			MenuUtil.CreateContextMenu(self, function(_, root)
				root:CreateTitle("AudioSwap")
				root:CreateRadio("Auto", function() return ns.db.manual == nil end, function() ns.SetManual(nil) end)
				root:CreateDivider()
				for _, name in ipairs(ns.ProfileNames()) do
					root:CreateRadio(name, function() return ns.db.manual == name end, function() ns.SetManual(name) end)
				end
				root:CreateDivider()
				root:CreateButton("Settings", ns.OpenSettings)
			end)
		end,
		OnTooltipShow = function(tt)
			tt:AddLine("AudioSwap")
			tt:AddLine((ns.current or "?") .. (ns.db.manual and " (manual)" or " (auto)"), 1, 1, 1)
			tt:AddLine("Left-click: pick profile  Right-click: settings", 0.7, 0.7, 0.7)
		end,
	})
	LibStub("LibDBIcon-1.0"):Register("AudioSwap", ldb, ns.db.minimap)
	return ldb
end

function ns.InitUI()
	local panel = buildPanel()
	local ldb = buildMinimap()
	ns.OnChange = function()
		ldb.text = ns.current
		if panel:IsVisible() and not refreshing then
			ns.Refresh()
		end
	end
end
