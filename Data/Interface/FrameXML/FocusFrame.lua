MAX_FOCUS_BUFFS = 6;

UnitReactionColor = {
	{ r = 1.0, g = 0.0, b = 0.0 },
	{ r = 1.0, g = 0.0, b = 0.0 },
	{ r = 1.0, g = 0.5, b = 0.0 },
	{ r = 1.0, g = 1.0, b = 0.0 },
	{ r = 0.0, g = 1.0, b = 0.0 },
	{ r = 0.0, g = 1.0, b = 0.0 },
	{ r = 0.0, g = 1.0, b = 0.0 },
	{ r = 0.0, g = 1.0, b = 0.0 },
};

function FocusFrame_OnLoad (self)
	self.statusCounter = 0;
	self.statusSign = -1;
	self.unitHPPercent = 1;

	self.buffStartX = 5;
	self.buffStartY = 32;
	self.buffSpacing = 3;

	self:RegisterForDrag("LeftButton");
	FocusFrame_Update(self);
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PLAYER_FOCUS_CHANGED");
	self:RegisterEvent("UNIT_HEALTH");
	self:RegisterEvent("UNIT_LEVEL");
	self:RegisterEvent("UNIT_FACTION");
	self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED");
	self:RegisterEvent("UNIT_AURA");
	self:RegisterEvent("PLAYER_FLAGS_CHANGED");
	self:RegisterEvent("PARTY_MEMBERS_CHANGED");
	self:RegisterEvent("RAID_TARGET_UPDATE");

	local frameLevel = FocusFrameTextureFrame:GetFrameLevel();
	FocusFrameHealthBar:SetFrameLevel(frameLevel-1);
	FocusFrameManaBar:SetFrameLevel(frameLevel-1);
	FocusFrameSpellBar:SetFrameLevel(frameLevel-1);

	local showmenu = function()
		ToggleDropDownMenu(1, nil, FocusFrameDropDown, "FocusFrame", 120, 10);
	end
	SecureUnitButton_OnLoad(self, "focus", showmenu);
end

function FocusFrame_Update (self)
	-- This check is here so the frame will hide when the target goes away
	-- even if some of the functions below are hooked by addons.
	if ( not UnitExists("focus") ) then
		self:Hide();
	else
		self:Show();

		-- Moved here to avoid taint from functions below
		TargetofFocus_Update();

		UnitFrame_Update(self);
		FocusFrame_CheckFaction(self);
		FocusDebuffButton_Update(self);
		FocusPortrait:SetAlpha(1.0);
	end
end

function FocusFrame_OnEvent (self, event, ...)
	UnitFrame_OnEvent(self, event, ...);

	local arg1 = ...;
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		FocusFrame_Update(self);
	elseif ( event == "PLAYER_FOCUS_CHANGED" ) then
		-- Moved here to avoid taint from functions below
		FocusFrame_Update(self);
		FocusFrame_UpdateRaidTargetIcon(self);
		CloseDropDownMenus();

		if ( UnitExists("focus") ) then
			if ( UnitIsEnemy("focus", "player") ) then
				PlaySound("igCreatureAggroSelect");
			elseif ( UnitIsFriend("player", "focus") ) then
				PlaySound("igCharacterNPCSelect");
			else
				PlaySound("igCreatureNeutralSelect");
			end
		end
	elseif ( event == "UNIT_FACTION" ) then
		if ( arg1 == "focus" or arg1 == "player" ) then
			FocusFrame_CheckFaction(self);
		end
	elseif ( event == "UNIT_AURA" ) then
		if ( arg1 == "focus" ) then
			FocusDebuffButton_Update(self);
		end
	elseif ( event == "PARTY_MEMBERS_CHANGED" ) then
		TargetofFocus_Update();
		FocusFrame_CheckFaction(self);
	elseif ( event == "RAID_TARGET_UPDATE" ) then
		FocusFrame_UpdateRaidTargetIcon(self);
	end
end

function FocusFrame_OnHide (self)
	PlaySound("INTERFACESOUND_LOSTTARGETUNIT");
	CloseDropDownMenus();
end

function FocusFrame_CheckFaction (self)
	if ( UnitPlayerControlled("focus") ) then
		local r, g, b;
		if ( UnitCanAttack("focus", "player") ) then
			-- Hostile players are red
			if ( not UnitCanAttack("player", "focus") ) then
				r = 0.0;
				g = 0.0;
				b = 1.0;
			else
				r = UnitReactionColor[2].r;
				g = UnitReactionColor[2].g;
				b = UnitReactionColor[2].b;
			end
		elseif ( UnitCanAttack("player", "focus") ) then
			-- Players we can attack but which are not hostile are yellow
			r = UnitReactionColor[4].r;
			g = UnitReactionColor[4].g;
			b = UnitReactionColor[4].b;
		elseif ( UnitIsPVP("focus") and not UnitIsPVPSanctuary("focus") and not UnitIsPVPSanctuary("player") ) then
			-- Players we can assist but are PvP flagged are green
			r = UnitReactionColor[6].r;
			g = UnitReactionColor[6].g;
			b = UnitReactionColor[6].b;
		else
			-- All other players are blue (the usual state on the "blue" server)
			r = 0.0;
			g = 0.0;
			b = 1.0;
		end
		FocusFrameNameBackground:SetVertexColor(r, g, b);
		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0);
	elseif ( UnitIsTapped("focus") and not UnitIsTappedByPlayer("focus") ) then
		FocusFrameNameBackground:SetVertexColor(0.5, 0.5, 0.5);
		FocusPortrait:SetVertexColor(0.5, 0.5, 0.5);
	else
		local reaction = UnitReaction("focus", "player");
		if ( reaction ) then
			local r, g, b;
			r = UnitReactionColor[reaction].r;
			g = UnitReactionColor[reaction].g;
			b = UnitReactionColor[reaction].b;
			FocusFrameNameBackground:SetVertexColor(r, g, b);
		else
			FocusFrameNameBackground:SetVertexColor(0, 0, 1.0);
		end
		FocusPortrait:SetVertexColor(1.0, 1.0, 1.0);
	end
end

function FocusFrame_OnUpdate (self, elapsed)
	if ( TargetofFocusFrame:IsShown() ~= UnitExists("focus-target") ) then
		TargetofFocus_Update();
	end
end

function FocusDebuffButton_Update (self)
	RefreshBuffs(self, 0, "focus", MAX_FOCUS_BUFFS);
end

function FocusFrame_HealthUpdate (self, elapsed, unit)
	if ( UnitIsPlayer(unit) ) then
		if ( (self.unitHPPercent > 0) and (self.unitHPPercent <= 0.2) ) then
			local alpha = 255;
			local counter = self.statusCounter + elapsed;
			local sign    = self.statusSign;
	
			if ( counter > 0.5 ) then
				sign = -sign;
				self.statusSign = sign;
			end
			counter = mod(counter, 0.5);
			self.statusCounter = counter;
	
			if ( sign == 1 ) then
				alpha = (127  + (counter * 256)) / 255;
			else
				alpha = (255 - (counter * 256)) / 255;
			end
			FocusPortrait:SetAlpha(alpha);
		end
	end
end

function FocusHealthCheck (self)
	if ( UnitIsPlayer("focus") ) then
		local unitHPMin, unitHPMax, unitCurrHP;
		unitHPMin, unitHPMax = self:GetMinMaxValues();
		unitCurrHP = self:GetValue();
		self:GetParent().unitHPPercent = unitCurrHP / unitHPMax;
		if ( UnitIsDead("focus") ) then
			FocusPortrait:SetVertexColor(0.35, 0.35, 0.35, 1.0);
		elseif ( UnitIsGhost("focus") ) then
			FocusPortrait:SetVertexColor(0.2, 0.2, 0.75, 1.0);
		elseif ( (self:GetParent().unitHPPercent > 0) and (self:GetParent().unitHPPercent <= 0.2) ) then
			FocusPortrait:SetVertexColor(1.0, 0.0, 0.0);
		else
			FocusPortrait:SetVertexColor(1.0, 1.0, 1.0, 1.0);
		end
	end
end

function FocusFrameDropDown_OnLoad (self)
	UIDropDownMenu_Initialize(self, FocusFrameDropDown_Initialize, "MENU");
end

function FocusFrameDropDown_Initialize (self)
	UnitPopup_ShowMenu(self, "FOCUS", "focus",SET_FOCUS, id);
end

function FocusFrame_UpdateRaidTargetIcon (self)
	local index = GetRaidTargetIndex("focus");
	if ( index ) then
		SetRaidTargetIconTexture(FocusRaidTargetIcon, index);
		FocusRaidTargetIcon:Show();
	else
		FocusRaidTargetIcon:Hide();
	end
end

function TargetofFocus_OnLoad (self)
	local frameLevel = FocusFrame:GetFrameLevel();
	TargetofFocusFrame:SetFrameLevel(frameLevel-1);

	UnitFrame_Initialize(self, "focus-target", TargetofFocusName, TargetofFocusPortrait,
		TargetofFocusHealthBar, TargetofFocusHealthBarText,
		TargetofFocusManaBar, TargetofFocusFrameManaBarText,
		TargetofFocusThreatIndicator, "player");
	SetTextStatusBarTextZeroText(TargetofFocusHealthBar, DEAD);
	self:RegisterEvent("UNIT_AURA");

	SecureUnitButton_OnLoad(self, "focus-target");
end

function TargetofFocus_Update (self, elapsed)
	if ( not self ) then
		self = TargetofFocusFrame;
	end

	local show;
	if ( SHOW_TARGET_OF_TARGET == "1" and UnitExists("focus") and UnitExists("focus-target") and --[[( not UnitIsUnit(PlayerFrame.unit, "focus") ) and ]]( UnitHealth("focus") > 0 ) ) then
		if ( ( SHOW_TARGET_OF_TARGET_STATE == "5" ) or
		     ( SHOW_TARGET_OF_TARGET_STATE == "4" and ( (GetNumRaidMembers() > 0) or (GetNumPartyMembers() > 0) ) ) or
		     ( SHOW_TARGET_OF_TARGET_STATE == "3" and ( (GetNumRaidMembers() == 0) and (GetNumPartyMembers() == 0) ) ) or
		     ( SHOW_TARGET_OF_TARGET_STATE == "2" and ( (GetNumPartyMembers() > 0) and (GetNumRaidMembers() == 0) ) ) or
		     ( SHOW_TARGET_OF_TARGET_STATE == "1" and ( GetNumRaidMembers() > 0 ) ) ) then
			show = true;
		end
	end

	if ( show ) then
		if ( not TargetofFocusFrame:IsShown() ) then
			TargetofFocusFrame:Show();
			Focus_Spellbar_AdjustPosition();
		end
		UnitFrame_Update(self);
		TargetofFocus_CheckDead();
		TargetofFocusHealthCheck();
		RefreshBuffs(TargetofFocusFrame, 0, "focus-target");
	else
		if ( TargetofFocusFrame:IsShown() ) then
			TargetofFocusFrame:Hide();
			Focus_Spellbar_AdjustPosition();
		end
	end
end

function TargetofFocus_CheckDead ()
	if ( (UnitHealth("focus-target") <= 0) and UnitIsConnected("focus-target") ) then
		TargetofFocusBackground:SetAlpha(0.9);
		TargetofFocusDeadText:Show();
	else
		TargetofFocusBackground:SetAlpha(1);
		TargetofFocusDeadText:Hide();
	end
end

function TargetofFocusHealthCheck ()
	if ( UnitIsPlayer("focus-target") ) then
		local unitHPMin, unitHPMax, unitCurrHP;
		unitHPMin, unitHPMax = TargetofFocusHealthBar:GetMinMaxValues();
		unitCurrHP = TargetofFocusHealthBar:GetValue();
		TargetofFocusFrame.unitHPPercent = unitCurrHP / unitHPMax;
		if ( UnitIsDead("focus-target") ) then
			TargetofFocusPortrait:SetVertexColor(0.35, 0.35, 0.35, 1.0);
		elseif ( UnitIsGhost("focus-target") ) then
			TargetofFocusPortrait:SetVertexColor(0.2, 0.2, 0.75, 1.0);
		elseif ( (TargetofFocusFrame.unitHPPercent > 0) and (TargetofFocusFrame.unitHPPercent <= 0.2) ) then
			TargetofFocusPortrait:SetVertexColor(1.0, 0.0, 0.0);
		else
			TargetofFocusPortrait:SetVertexColor(1.0, 1.0, 1.0, 1.0);
		end
	end
end


function SetFocusSpellbarAspect()
	local frameText = getglobal(FocusFrameSpellBar:GetName().."Text");
	if ( frameText ) then
		frameText:SetFontObject(SystemFont_Shadow_Small);
		frameText:ClearAllPoints();
		frameText:SetPoint("TOP", FocusFrameSpellBar, "TOP", 0, 4);
	end

	local frameBorder = getglobal(FocusFrameSpellBar:GetName().."Border");
	if ( frameBorder ) then
		frameBorder:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border-Small");
		frameBorder:SetWidth(150);
		frameBorder:SetHeight(49);
		frameBorder:ClearAllPoints();
		frameBorder:SetPoint("TOP", FocusFrameSpellBar, "TOP", 0, 20);
	end

	local frameFlash = getglobal(FocusFrameSpellBar:GetName().."Flash");
	if ( frameFlash ) then
		frameFlash:SetTexture("Interface\\CastingBar\\UI-CastingBar-Flash-Small");
		frameFlash:SetWidth(150);
		frameFlash:SetHeight(49);
		frameFlash:ClearAllPoints();
		frameFlash:SetPoint("TOP", FocusFrameSpellBar, "TOP", 0, 20);
	end
end

function Focus_Spellbar_OnLoad (self)
	self:RegisterEvent("PLAYER_FOCUS_CHANGED");
	self:RegisterEvent("CVAR_UPDATE");
	self:RegisterEvent("VARIABLES_LOADED");
	
	CastingBarFrame_OnLoad(self, "focus", false);

	local barIcon = getglobal(self:GetName().."Icon");
	barIcon:Show();
	barIcon:ClearAllPoints();
	barIcon:SetPoint("RIGHT", self:GetName(), "LEFT", -5, 0);

	SetFocusSpellbarAspect();
	
	--The target casting bar has less room for text than most, so shorten it
	getglobal(self:GetName().."Text"):SetWidth(115)
	-- check to see if the castbar should be shown
	if ( GetCVar("showTargetCastbar") == "0") then
		self.showCastbar = false;	
	end
end

function Focus_Spellbar_OnEvent (self, event, ...)
	local arg1 = ...
	
	--	Check for target specific events
	if ( (event == "VARIABLES_LOADED") or ((event == "CVAR_UPDATE") and (arg1 == "SHOW_TARGET_CASTBAR")) ) then
		if ( GetCVar("showTargetCastbar") == "0") then
			self.showCastbar = false;
		else
			self.showCastbar = true;
		end
		
		if ( not self.showCastbar ) then
			self:Hide();
		elseif ( self.casting or self.channeling ) then
			self:Show();
		end
		return;
	elseif ( event == "PLAYER_FOCUS_CHANGED" ) then
		-- check if the new target is casting a spell
		local nameChannel  = UnitChannelInfo(self.unit);
		local nameSpell  = UnitCastingInfo(self.unit);
		if ( nameChannel ) then
			event = "UNIT_SPELLCAST_CHANNEL_START";
			arg1 = "focus";
		elseif ( nameSpell ) then
			event = "UNIT_SPELLCAST_START";
			arg1 = "focus";
		else
			self.casting = nil;
			self.channeling = nil;
			self:SetMinMaxValues(0, 0);
			self:SetValue(0);
			self:Hide();
			return;
		end
		-- The position depends on the classification of the target
		Focus_Spellbar_AdjustPosition();
	end
	CastingBarFrame_OnEvent(self, event, arg1, select(2, ...));
end

function Focus_Spellbar_AdjustPosition ()
	local yPos = 3;
	if ( FocusFrame.debuffTotal > 3 ) then
		yPos = 27;
	elseif ( TargetofFocusFrame:IsShown() ) then
		yPos = 25;
	elseif ( FocusFrame.debuffTotal > 0 ) then
		yPos = 15
	end
	FocusFrameSpellBar:SetPoint("BOTTOM", "FocusFrame", "BOTTOM", 15, -yPos);
end

FOCUS_FRAME_LOCKED = true;
function FocusFrame_IsLocked()
	return FOCUS_FRAME_LOCKED;
end
function FocusFrame_SetLock(locked)
	FOCUS_FRAME_LOCKED = locked;
end

function FocusFrame_OnDragStart(self, button)
	FOCUS_FRAME_MOVING = false;
	if ( not FOCUS_FRAME_LOCKED ) then
		local cursorX, cursorY = GetCursorPosition();
		self:SetFrameStrata("DIALOG");
		self:StartMoving();
		self:ClearAllPoints();
		self:SetPoint("TOP", nil, "BOTTOMLEFT", cursorX*GetScreenWidthScale(), cursorY*GetScreenHeightScale());
		FOCUS_FRAME_MOVING = true;
	end
end

function FocusFrame_OnDragStop(self)
	if ( not FOCUS_FRAME_LOCKED and FOCUS_FRAME_MOVING ) then
		self:StopMovingOrSizing();
		self:SetFrameStrata("BACKGROUND");
		self:ClearAllPoints();
		
		local x, _ = self:GetCenter();
		local y = self:GetTop();
		self:SetPoint("TOP", nil, "BOTTOMLEFT", x, y);
		ValidateFramePosition(self, 25);
		-- Save the end positions
		-- SAVE;
		FOCUS_FRAME_MOVING = false;
	end
end

