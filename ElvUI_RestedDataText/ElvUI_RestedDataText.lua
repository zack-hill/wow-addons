local E, L, V, P, G = unpack(ElvUI)
local DT = E:GetModule('DataTexts')
local B = E:GetModule('Bags')
-- GLOBALS: ElvDB

local wipe, pairs, ipairs, sort = wipe, pairs, ipairs, sort
local format, strjoin, tinsert = format, strjoin, tinsert

local _G = _G
local EasyMenu = EasyMenu
local IsLoggedIn = IsLoggedIn
local IsShiftKeyDown = IsShiftKeyDown

local resetInfoFormatter = strjoin('', '|cffaaaaaa', L["Reset Character Data: Hold Shift + Right Click"], '|r')

local PRIEST_COLOR = RAID_CLASS_COLORS.PRIEST

local menuList, myRested = {}, {}
local iconString = '|T%s:16:16:0:0:64:64:4:60:4:60|t'
local db

local function sortFunction(a, b)
	if a.level == b.level then
		if a.level == 70 then
			return a.name < b.name
		end
	else
		if a.level == 70 or b.level == 70 then
			return a.level < b.level
		elseif a.restedPercent == b.restedPercent then
			return a.level < b.level
		else
			return a.restedPercent > b.restedPercent
		end
	end
	return 
end

local function deleteCharacter(_, realm, name)
	ElvDB.rested[realm][name] = nil
	ElvDB.class[realm][name] = nil
	ElvDB.faction[realm][name] = nil
	ElvDB.race[realm][name] = nil

	DT:ForceUpdate_DataText('Rested')
end

local function round(num, decimals)
    local mult = 10^(decimals or 0)
    
    return Round(num * mult) / mult
end

local function updateRested(self, updateAll)
	if updateAll then
		wipe(myRested)
		wipe(menuList)

		tinsert(menuList, { text = '', isTitle = true, notCheckable = true })
		tinsert(menuList, { text = 'Delete Character', isTitle = true, notCheckable = true })

		local realmN = 1
		for realm in pairs(ElvDB.serverID[E.serverID]) do
			tinsert(menuList, realmN, { 
				text = 'Delete All - '..realm, 
				notCheckable = true, 
				func = function() wipe(ElvDB.rested[realm]) DT:ForceUpdate_DataText('Rested') end 
			})
			realmN = realmN + 1
			for name in pairs(ElvDB.rested[realm]) do
				local faction = ElvDB.faction[realm][name]
				local restedData = ElvDB.rested[realm][name]
				local race = ElvDB.race[realm][name]

				if restedData then
					local color = E:ClassColor(ElvDB.class[realm][name]) or PRIEST_COLOR

					local restedPercentStart = (restedData.rested / restedData.xpMax) * 100
					local now = time()
					local secondsSinceUpdate = now - restedData.updated

					-- Base 5% every 8 hours
					local restedRatePerHour = 5/8
					local nonRestedRatePerHour = 1.25/8
					local effectiveRestingRatePerHour = restedData.resting and restedRatePerHour or nonRestedRatePerHour
					local restedCap = 150

					if race == 'Pandaren' then
						effectiveRestingRatePerHour = effectiveRestingRatePerHour * 2
						restedCap = restedCap * 2
					end

					local restedPercentAccrued = effectiveRestingRatePerHour * (secondsSinceUpdate / 3600)
					local restedPercentProjected = min(restedCap, restedPercentStart + restedPercentAccrued)
					local restedPercentProjected = round(restedPercentProjected, 1)

					-- TODO: Make level text gray if capped
					local levelText = format('Level %0d', restedData.level)
					local restedValueText = restedData.level == 70 and '' or format(' - %0d%% Rested', restedPercentProjected)
					local restingStatusText = (restedData.resting or restedPercentProjected == restedCap) and '' or '|cFFFF0000[Not Resting]|r '
					local text = restingStatusText .. levelText ..  restedValueText

					tinsert(myRested, {
							name = name,
							realm = realm,
							faction = faction or '',
							level = restedData.level,
							xp = restedData.xp,
							restedPercent = restedPercentProjected,
							text = text,
							r = color.r, 
							g = color.g, 
							b = color.b,
					})

					tinsert(menuList, {
						text = format('%s - %s', name, realm),
						notCheckable = true,
						func = function() deleteCharacter(self, realm, name) end
					})
				end
			end
		end
	else
		for _, info in ipairs(myRested) do
			if info.name == E.myname and info.realm == E.myrealm then
				-- TODO: Consider adding this path back to update only current line?
				-- info.amount = ElvDB.rested[E.myrealm][E.myname]
				-- info.amountText = E:FormatMoney(ElvDB.rested[E.myrealm][E.myname], style, textOnly)

				break
			end
		end
	end
end

local function OnEvent(self, event)
	if not IsLoggedIn() then return end

	if not db then
		db = E.global.datatexts.settings[self.name]
	end

	-- TODO: Clean up this init code
	if not ElvDB.race then
		ElvDB.race = {}
	end

	if not ElvDB.race[E.myrealm] then
		ElvDB.race[E.myrealm] = {}
	end

	if not ElvDB.rested then
		ElvDB.rested = {}
	end

	if not ElvDB.rested[E.myrealm] then
		ElvDB.rested[E.myrealm] = {}
	end

	ElvDB.race[E.myrealm][E.myname] = UnitRace('player')
	
	local level = UnitLevel('player')
	local xp = UnitXP('player')
	local xpMax = UnitXPMax('player')
	local rested = GetXPExhaustion() or 0
	local resting = IsResting()

	ElvDB.rested[E.myrealm][E.myname] = {
		level = UnitLevel('player'),
		xp = UnitXP('player'),
		xpMax = xpMax,
		rested = GetXPExhaustion() or 0,
		resting = IsResting(),
		updated = time(),
	}

	updateRested(self, event == 'ELVUI_FORCE_UPDATE')

	-- TODO: Change this text?
	self.text:SetText('Rested')
end

local function Click(self, btn)
	if btn == 'RightButton' then
		if IsShiftKeyDown() then
			E:SetEasyMenuAnchor(E.EasyMenu, self)
			EasyMenu(menuList, E.EasyMenu, nil, nil, nil, 'MENU')
		end
	end
end

local function OnEnter()
	DT.tooltip:ClearLines()

	DT.tooltip:AddLine(L["Character: "])

	sort(myRested, sortFunction)

	for _, g in ipairs(myRested) do
		local nameLine = ''
		if g.faction ~= '' and g.faction ~= 'Neutral' then
			nameLine = format([[|TInterface\FriendsFrame\PlusManz-%s:14|t ]], g.faction)
		end

		local toonName = format('%s%s%s', nameLine, g.name, (g.realm and g.realm ~= E.myrealm and ' - '..g.realm) or '')
		DT.tooltip:AddDoubleLine((g.name == E.myname and toonName..[[ |TInterface\COMMON\Indicator-Green:14|t]]) or toonName, g.text, g.r, g.g, g.b, 1, 1, 1)
	end

	DT.tooltip:AddLine(' ')
	DT.tooltip:AddLine(resetInfoFormatter)
	DT.tooltip:Show()
end

-- TODO: Register proper hooks, make sure it updates on logout
DT:RegisterDatatext('Rested', nil, {}, OnEvent, nil, Click, OnEnter, nil, L["Rested"])
