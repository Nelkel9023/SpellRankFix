local ADDON = ...

local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"
local MAX_ACTION_SLOT = 120

local wipe = wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

local frame = CreateFrame("Frame")
local enabled = true
local scanning = false
local best = {}
local excludes = {}
local DB

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99SpellRankFix|r: " .. msg)
end

local function Trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ParseRank(rank)
	if type(rank) == "string" then
		return tonumber(rank:match("%d+"))
	end
end

local function ParseSpellRank(text)
	local name, rank = text:match("^(.-)%s*[%(]?%s*[Rr]ank%s*(%d+)%s*[%)]?$")
	if name then
		name = Trim(name)
		if name ~= "" then
			return name, tonumber(rank)
		end
	end
	name, rank = text:match("^(.-)%s*[%(]?%s*(%d+)%s*[%)]?$")
	if name then
		name = Trim(name)
		if name ~= "" then
			return name, tonumber(rank)
		end
	end
	return Trim(text), nil
end

local function BuildBestSpells()
	wipe(best)
	for tab = 1, (GetNumSpellTabs() or 0) do
		local _, _, offset, numSpells = GetSpellTabInfo(tab)
		offset = offset or 0
		numSpells = numSpells or 0
		for i = offset + 1, offset + numSpells do
			local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
			if name then
				local r = ParseRank(rank) or 0
				local cur = best[name]
				if not cur or r > (cur % 1000) then
					best[name] = i * 1000 + r
				end
			end
		end
	end
end

local function GetActionSpell(slot)
	local actionType, id, subType, spellId = GetActionInfo(slot)
	if actionType ~= "spell" then
		return
	end
	local want = ParseRank(subType)
	local name, rank
	if type(spellId) == "number" and spellId > 0 then
		name, rank = GetSpellInfo(spellId)
		if name and want and ParseRank(rank) and want ~= ParseRank(rank) then
			name, rank = nil, nil
		end
	end
	if not name and type(id) == "number" and id > 0 then
		local ok, n, r = pcall(GetSpellName, id, BOOKTYPE_SPELL)
		if ok and n and (not want or not ParseRank(r) or want == ParseRank(r)) then
			name, rank = n, r
		end
	end
	if not name then
		return
	end
	if not rank and type(subType) == "string" then
		rank = subType
	end
	return name, rank
end

local queue = {}
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local due = false
	for i = #queue, 1, -1 do
		if now >= queue[i] then
			queue[i] = queue[#queue]
			queue[#queue] = nil
			due = true
		end
	end
	if #queue == 0 then
		self:Hide()
	end
	if due then
		frame.Scan()
	end
end)

local function Schedule(delay)
	queue[#queue + 1] = GetTime() + (delay or 0)
	ticker:Show()
end

function frame.Scan(force)
	if scanning or not excludes or (not enabled and not force) then
		return nil
	end
	if GetCursorInfo() or (InCombatLockdown and InCombatLockdown()) then
		if force then
			return nil
		end
		Schedule(2)
		return 0
	end
	scanning = true
	BuildBestSpells()
	local fixed = 0
	for slot = 1, MAX_ACTION_SLOT do
		if HasAction(slot) then
			local name, rank = GetActionSpell(slot)
			if name then
				local r = ParseRank(rank) or 0
				local packed = best[name]
				if packed and excludes[name] ~= r then
					local er = packed % 1000
					if er > r then
						PickupSpell((packed - er) / 1000, BOOKTYPE_SPELL)
						if GetCursorInfo() then
							PlaceAction(slot)
							ClearCursor()
							fixed = fixed + 1
						end
					end
				end
			end
		end
	end
	scanning = false
	if fixed > 0 then
		Schedule(3)
	end
	return fixed
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		if type(SpellRankFixDB) ~= "table" then
			SpellRankFixDB = {}
		end
		DB = SpellRankFixDB
		if type(DB.exclude) ~= "table" then
			DB.exclude = {}
		end
		excludes = DB.exclude
		if DB.enabled == false then
			enabled = false
		end
		SLASH_SPELLRANKFIX1 = "/rankfix"
		SlashCmdList["SPELLRANKFIX"] = function(msg)
			local cmd, rest = tostring(msg):match("^(%S*)%s*(.-)$")
			rest = Trim(rest)
			if cmd:lower() == "on" then
				DB.enabled = true
				enabled = true
				Print("auto fix on")
			elseif cmd:lower() == "off" then
				DB.enabled = false
				enabled = false
				Print("auto fix off (use /rankfix to fix now)")
			elseif cmd:lower() == "exclude" then
				if rest == "" then
					Print("usage: /rankfix exclude Frostbolt(Rank 1)")
					return
				end
				local name, rank = ParseSpellRank(rest)
				if not name or not rank then
					Print("rank required, e.g. /rankfix exclude Frostbolt(Rank 1)")
					return
				end
				excludes[name] = rank
				Print(("%s Rank %d kept as-is"):format(name, rank))
			elseif cmd:lower() == "unexclude" then
				if rest == "" then
					Print("usage: /rankfix unexclude Frostbolt")
					return
				end
				local name = ParseSpellRank(rest)
				if excludes[name] then
					excludes[name] = nil
					Print(("%s exclusion removed"):format(name))
				else
					Print(("%s is not excluded"):format(name))
				end
			elseif cmd:lower() == "list" then
				local names = {}
				for n in pairs(excludes) do
					names[#names + 1] = n
				end
				if #names == 0 then
					Print("no excluded spells")
					return
				end
				table.sort(names)
				for _, n in ipairs(names) do
					Print(("%s (Rank %d)"):format(n, excludes[n]))
				end
			else
				local n = frame.Scan(true)
				if not n then
					Print("scan blocked (combat or cursor busy), try again")
				elseif n > 0 then
					Print(("upgraded %d action slot(s)"):format(n))
				else
					Print("all ranks up to date")
				end
			end
		end
		return
	end
	if event == "ACTIVE_TALENT_GROUP_CHANGED" then
		Schedule(0)
		Schedule(1)
	elseif event == "PLAYER_LEVEL_UP" or event == "PLAYER_TALENT_UPDATE" then
		Schedule(1)
	elseif event == "SPELLS_CHANGED" then
		Schedule(0.5)
	elseif event == "PLAYER_ENTERING_WORLD" then
		Schedule(2)
	end
end)
