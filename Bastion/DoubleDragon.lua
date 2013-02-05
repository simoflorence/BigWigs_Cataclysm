--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Valiona and Theralion", 758, 157)
if not mod then return end
mod:RegisterEnableMob(45992, 45993)

--------------------------------------------------------------------------------
-- Locals
--

local phaseCount = 0
local devouringFlames = "~"..mod:SpellName(86840)
local theralion = EJ_GetSectionInfo(2994)
local valiona = EJ_GetSectionInfo(2985)
local emTargets = mod:NewTargetList()
local markWarned = false

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.phase_switch = "Phase Switch"
	L.phase_switch_desc = "Warning for phase switches."

	L.phase_bar = "%s landing"
	L.breath_message = "Deep Breaths incoming!"
	L.dazzling_message = "Swirly zones incoming!"

	L.blast_message = "Falling Blast" --Sounds better and makes more sense than Twilight Blast (the user instantly knows something is coming from the sky at them)
	L.engulfingmagic_say = "Engulf"

	L.valiona_trigger = "Theralion, I will engulf the hallway. Cover their escape!"
	L.win_trigger = "At least... Theralion dies with me..."

	L.twilight_shift = "%2$dx shift on %1$s"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		{86788, "ICON", "FLASH", "WHISPER"}, {88518, "FLASH"}, 86059, 86840,
		{86622, "FLASH", "SAY", "WHISPER"}, 86408, 86369, 93051,
		"proximity", "phase_switch", "berserk", "bosskill"
	}, {
		[86788] = valiona,
		[86622] = theralion,
		[93051] = "heroic",
		proximity = "general",
	}
end

function mod:OnBossEnable()
	-- Heroic
	self:Log("SPELL_AURA_APPLIED_DOSE", "TwilightShift", 93051)

	-- Phase Switch -- should be able to do this easier once we get Transcriptor logs
	self:Log("SPELL_CAST_START", "DazzlingDestruction", 86408)
	self:Yell("DeepBreath", L["valiona_trigger"])
	self:Emote("DeepBreathCast", self:SpellName(86059)) -- Deep Breath

	self:Log("SPELL_AURA_APPLIED", "BlackoutApplied", 86788)
	self:Log("SPELL_AURA_REMOVED", "BlackoutRemoved", 86788)
	self:Log("SPELL_CAST_START", "DevouringFlames", 86840)

	self:Log("SPELL_AURA_APPLIED", "EngulfingMagicApplied", 86622)
	self:Log("SPELL_AURA_REMOVED", "EngulfingMagicRemoved", 86622)

	self:Log("SPELL_CAST_START", "TwilightBlast", 86369)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:RegisterUnitEvent("UNIT_AURA", "MeteorCheck", "player")

	self:Death("Deaths", 45992, 45993)
end

function mod:OnEngage()
	markWarned = false
	self:Bar(86840, devouringFlames, 25, 86840)
	self:Bar(86788, 86788, 11, 86788) -- Blackout
	self:Bar("phase_switch", L["phase_bar"]:format(theralion), 103, 60639)
	self:OpenProximity("proximity", 8)
	self:Berserk(600)
	phaseCount = 0
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local function checkTarget(sGUID, spellId)
		local bossId = UnitGUID("boss2") == sGUID and "boss2target" or "boss1target"
		if not UnitName(bossId) then return end --The first is sometimes delayed longer than 0.3
		if UnitIsUnit(bossId, "player") then
			mod:LocalMessage(spellId, CL["you"]:format(L["blast_message"]), "Personal", spellId, "Long")
		end
	end
	function mod:TwilightBlast(args)
		self:ScheduleTimer(checkTarget, 0.3, args.sourceGUID, args.spellId)
	end
end

local function valionaHasLanded()
	mod:StopBar("~"..mod:SpellName(86622))
	mod:Message("phase_switch", L["phase_bar"]:format(valiona), "Positive", 60639)
	mod:Bar(86840, devouringFlames, 26, 86840)
	mod:Bar(86788, 86788, 11, 86788) -- Blackout
	mod:OpenProximity("proximity", 8)
end

local function theralionHasLanded()
	mod:StopBar(86788) -- Blackout
	mod:StopBar(devouringFlames)
	mod:Bar("phase_switch", L["phase_bar"]:format(valiona), 130, 60639)
	mod:CloseProximity()
end

function mod:TwilightShift(args)
	self:Bar(args.spellId, args.spellName, 20, args.spellId)
	if args.amount > 3 then
		self:TargetMessage(args.spellId, L["twilight_shift"], args.destName, "Important", args.spellId, nil, args.amount)
	end
end

-- When Theralion is landing he casts DD 3 times, with a 5 second interval.
function mod:DazzlingDestruction(args)
	phaseCount = phaseCount + 1
	if phaseCount == 1 then
		self:Message(args.spellId, L["dazzling_message"], "Important", args.spellId, "Alarm")
	elseif phaseCount == 3 then
		self:ScheduleTimer(theralionHasLanded, 5)
		self:Message("phase_switch", L["phase_bar"]:format(theralion), "Positive", 60639)
		phaseCount = 0
	end
end

-- She emotes 3 times, every time she does a breath
function mod:DeepBreathCast()
	phaseCount = phaseCount + 1
	self:Message(86059, L["breath_message"], "Important", 92194, "Alarm")
	if phaseCount == 3 then
		self:Bar("phase_switch", L["phase_bar"]:format(theralion), 105, 60639)
		phaseCount = 0
	end
end

-- Valiona does this when she fires the first deep breath and begins the landing phase
-- It only triggers once from her yell, not 3 times.
function mod:DeepBreath()
	self:Bar("phase_switch", L["phase_bar"]:format(valiona), 40, 60639)
	self:ScheduleTimer(valionaHasLanded, 40)
end

function mod:BlackoutApplied(args)
	if UnitIsUnit(args.destName, "player") then
		self:Flash(args.spellId)
	else
		self:PlaySound(args.spellId, "Alert")
	end
	self:TargetMessage(args.spellId, args.spellName, args.destName, "Personal", args.spellId, "Alert")
	self:Bar(args.spellId, args.spellName, 45, args.spellId)
	self:Whisper(args.spellId, args.destName, args.spellName)
	self:PrimaryIcon(args.spellId, args.destName)
	self:CloseProximity()
end

function mod:BlackoutRemoved(args)
	self:OpenProximity("proximity", 8)
	self:PrimaryIcon(args.spellId)
	self:Bar(args.spellId, args.spellName, 40, args.spellId) -- make sure to remove bar when it's removed
end

local function markRemoved()
	markWarned = false
end

do
	local marked = mod:SpellName(88518)
	function mod:MeteorCheck(unit)
		if not markWarned and UnitDebuff(unit, marked) then
			self:Flash(88518)
			self:LocalMessage(88518, CL["you"]:format(marked), "Personal", 88518, "Long")
			markWarned = true
			self:ScheduleTimer(markRemoved, 7)
		end
	end
end

function mod:DevouringFlames(args)
	self:Bar(args.spellId, devouringFlames, 42, args.spellId) -- make sure to remove bar when it takes off
	self:Message(args.spellId, args.spellName, "Important", args.spellId, "Alert")
end

do
	local scheduled = nil
	local function emWarn(spellName, spellId)
		mod:TargetMessage(spellId, spellName, emTargets, "Personal", spellId, "Alarm")
		mod:Bar(spellId, "~"..spellName, 37, spellId)
		scheduled = nil
	end
	function mod:EngulfingMagicApplied(args)
		if UnitIsUnit(args.destName, "player") then
			self:Say(args.spellId, L["engulfingmagic_say"])
			self:Flash(args.spellId)
			self:OpenProximity("proximity", 10)
		end
		emTargets[#emTargets + 1] = args.destName
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(emWarn, 0.3, args.spellName, args.spellId)
		end
		self:Whisper(args.spellId, args.destName, args.spellName)
	end
end

function mod:EngulfingMagicRemoved(args)
	if UnitIsUnit(args.destName, "player") then
		self:CloseProximity()
	end
end

do
	local count = 0
	function mod:Deaths()
		--Prevent the module from re-enabling in the second or so after 1 boss dies
		count = count + 1
		if count == 2 then
			self:Win()
		end
	end
end

