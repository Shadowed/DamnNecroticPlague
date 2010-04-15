NecroticPlague = select(2, ...)
local PLAGUE_DEBUFF = GetSpellInfo(73787)
local TICK_INTERVALS = 5
local TICK_BASE = 150000
local PER_STACK = 50000
PLAGUE_DEBUFF = "Faerie Fire"

function NecroticPlague:ADDON_LOADED(addon)
	if( addon ~= "DamnNecroticPlague" ) then return end
	DamnNecPlagueDB = DamnNecPlagueDB or {locked = true, scale = 1.0}
	self.db = DamnNecPlagueDB
	
	self.evtFrame:UnregisterEvent("ADDON_LOADED")
end

-- Display for the targets stance
local backdrop = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1}}

local function monitorDebuff(self, elapsed)
	self.timeElapsed = self.timeElapsed + elapsed
	if( self.timeElapsed < 0.50 ) then return end
	self.timeElapsed = self.timeElapsed - 0.50
	
	local time = GetTime()
	local stack, _, _, endTime = select(4, UnitDebuff("target", PLAGUE_DEBUFF))
	if( not stack or endTime <= time ) then
		self:Hide()
		return
	end	
	
	stack = stack and stack > 0 and stack or 1
	local ticksLeft = math.ceil((endTime - time) / TICK_INTERVALS)
	local health, maxHealth = UnitHealth("target"), UnitHealthMax("target")
	local damage = TICK_BASE + ((stack - 1) * PER_STACK)
	local percent = health / maxHealth
	local percentDamage = damage / maxHealth
	
	first, second, third = (percent - percentDamage), (percent - percentDamage * 2), (percent - percentDamage * 3)
	first = first < 0 and 0 or first
	second = second < 0 and 0 or second
	third = third < 0 and 0 or third
	
	if( ticksLeft >= 3 ) then
		self.text:SetFormattedText("1st: |cffff2020%d%%|r / 2nd |cffff2020%d%%|r / 3rd |cffff2020%d%%|r", first * 100, second * 100, third * 100)
	elseif( ticksLeft >= 2 ) then
		self.text:SetFormattedText("1st: --- / 2nd |cffff2020%d%%|r / 3rd |cffff2020%d%%|r", first * 100, second * 100)
	else
		self.text:SetFormattedText("1st: --- / 2nd --- / 3rd |cffff2020%d%%|r", first * 100)
	end
end

function NecroticPlague:CreateDisplay()
	if( self.frame ) then return end
	self.frame = CreateFrame("Frame", nil, UIParent)
	self.frame:SetScale(self.db.scale)
	self.frame:SetBackdrop(backdrop)
	self.frame:SetBackdropColor(0, 0, 0, 1.0)
	self.frame:SetBackdropBorderColor(0.30, 0.30, 0.30, 1.0)
	self.frame:SetClampedToScreen(true)
	self.frame:SetMovable(true)
	self.frame:EnableMouse(true)
	self.frame:SetWidth(175)
	self.frame:SetHeight(20)
	self.frame:RegisterForDrag("LeftButton")
	self.frame:SetScript("OnUpdate", monitorDebuff)
	self.frame:Hide()
	self.frame.timeElapsed = 0

	-- Positioning
	self.frame:SetScript("OnDragStart", function(self)
		if( not NecroticPlague.db.locked ) then
			self.isMoving = true
			self:StartMoving()
		end
	end)
	
	self.frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		
		local scale = self:GetEffectiveScale()
		NecroticPlague.db.x = self:GetLeft() * scale
		NecroticPlague.db.y = self:GetTop() * scale
	end)
	
	if( self.db.x and self.db.y ) then
		local scale = self.frame:GetEffectiveScale()
		self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.x / scale, self.db.y / scale)
	else
		self.frame:SetPoint("CENTER", UIParent, "CENTER")
	end
	
	self.frame.text = self.frame:CreateFontString(nil, "ARTWORK")
	self.frame.text:SetFontObject(GameFontHighlightSmall)
	self.frame.text:SetPoint("LEFT", self.frame, "LEFT")
	self.frame.text:SetWidth(175)
	self.frame.text:SetHeight(20)
end

function NecroticPlague:UNIT_AURA(unit)
	if( unit ~= "target" ) then
		return
	elseif( UnitIsPlayer("target") and not UnitIsEnemy("player", "target") ) then
		self.frame:Hide()
		return
	end

	if( UnitDebuff(unit, PLAGUE_DEBUFF) ) then
		monitorDebuff(self.frame, 0.50)
		self.frame:Show()
	else
		self.frame:Hide()
	end
end

function NecroticPlague:PLAYER_TARGET_CHANGED()
	if( not UnitExists("target") ) then
		self.frame:Hide()
	else
		self:UNIT_AURA("target")
	end
end

local instanceType
function NecroticPlague:ZONE_CHANGED_NEW_AREA()
	instance = select(2, IsInInstance())
	if( instance == "raid" and instanceType ~= instance ) then
		self:CreateDisplay()
		self.evtFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
		self.evtFrame:RegisterEvent("UNIT_AURA")
	elseif( instanceType == "raid" and instanceType ~= instance ) then
		self.evtFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self.evtFrame:UnregisterEvent("UNIT_AURA")
	end
	
	instanceType = instance
end

NecroticPlague.PLAYER_ENTERING_WORLD = NecroticPlague.ZONE_CHANGED_NEW_AREA

function NecroticPlague:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99Plague Tracker|r: %s", msg))
end

-- Event thing
local function OnEvent(self, event, ...)
	NecroticPlague[event](NecroticPlague, ...)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnEvent)
NecroticPlague.evtFrame = frame


SLASH_NECROTICPLAGUE1 = "/necroticp"
SLASH_NECROTICPLAGUE2 = "/necroticplague"
SlashCmdList["NECROTICPLAGUE"] = function(msg)
	msg = string.lower(msg or "")
	
	local self = NecroticPlague
	local cmd, arg = string.split(" ", msg)
	if( cmd == "scale" ) then
		arg = tonumber(string.match(arg, "([0-9]+)"))
		if( not arg or arg <= 0 ) then
			self:Print("Invalid scale entered, it must be a number and cannot be 0 or lower.")
			return
		end
		
		self.db.scale = (arg or 100) / 100
		self:Print(string.format("Widget scale set to %.2f.", self.db.scale))
	
		if( self.frame ) then
			self.frame:SetScale(self.db.scale)
		end

	elseif( cmd == "lock" ) then
		self.db.locked = not self.db.locked
	
		if( self.db.locked ) then
			self:Print("Plague widget locked and start to update again")
			
			if( self.frame ) then
				instanceType = nil
				self.frame:Hide()
				self.frame:SetScript("OnUpdate", monitorDebuff)
				self.evtFrame:SetScript("OnEvent", OnEvent)
				self:PLAYER_ENTERING_WORLD()
			end
		else
			self:Print("Plague widget unlocked, will not update until you relock it.")
			
			self:CreateDisplay()
			self.frame:SetScript("OnUpdate", nil)
			self.evtFrame:SetScript("OnEvent", nil)
			self.frame.text:SetText("1st: |cffff202050%|r / 2nd: |cffff202025%|r / 3rd: |cffff202010%|r")
			self.frame:Show()
		end
	else
		self:Print("Slash commands")
		DEFAULT_CHAT_FRAME:AddMessage("/necroticp scale <number> - Scale of the widget, 55% for 55% scaling and so on")
		DEFAULT_CHAT_FRAME:AddMessage("/necroticp lock - Toggles locking for the text widget")
	end
end