AddCSLuaFile!

Moonpanel.FocusDuration = 0.4

Moonpanel.__focusHolding or= {}
Moonpanel.__focusPrediction = nil

if CLIENT
	focusDebug = CreateClientConVar "moonpanel_debug_focus", "0", true, false,
		"Log predicted and replicated Moonpanel focus transitions"
	Moonpanel.FocusDebugPrint = (event, details = "") ->
		return unless focusDebug\GetBool!
		MsgC Color(120, 210, 255), "[Moonpanel Focus] ", event,
			" ct=", string.format("%.3f", CurTime!),
			" rt=", string.format("%.3f", RealTime!),
			" ", details, "\n"
else
	Moonpanel.FocusDebugPrint = (...) ->

if CLIENT
	hook.Add "Think", "TheMP Focus Prediction", () ->
		prediction = Moonpanel.__focusPrediction
		return unless prediction
		ply = LocalPlayer!
		return unless IsValid ply
		nwState = ply\GetNW2Bool "TheMP Focused"
		if not prediction.acknowledged and RealTime! >= prediction.deadline
			Moonpanel.FocusDebugPrint "prediction-timeout", "state=#{tostring(prediction.state)} nw=#{tostring(nwState)}"
			Moonpanel.__focusPrediction = nil

------------------------------------------------
-- Gets whether the player is focused or not. --
------------------------------------------------
Moonpanel.IsFocused = (ply = CLIENT and LocalPlayer!) =>
	return false unless IsValid ply
	if CLIENT and ply == LocalPlayer! and Moonpanel.__focusPrediction
		return Moonpanel.__focusPrediction.state == true
	ply\GetNW2Bool "TheMP Focused"

----------------------------------------------------------------------
-- Gets the focus angle of the player, which gets set automatically --
-- by Moonpanel:SetFocused(ply, state).                             --
----------------------------------------------------------------------
Moonpanel.GetFocusAngles = (ply = CLIENT and LocalPlayer!) =>
	return Angle! unless IsValid ply
	if CLIENT and ply == LocalPlayer! and Moonpanel.__focusPrediction and
		Moonpanel.__focusPrediction.state
		return Moonpanel.__focusPrediction.angles
	if Moonpanel.PillarFocusAngles and Moonpanel.PillarFocusAngles[ply]
		return Moonpanel.PillarFocusAngles[ply]
    ply\GetNW2Angle "TheMP FocusAngle"

Moonpanel.GetFocusTime = (ply = CLIENT and LocalPlayer!) =>
	return 0 unless IsValid ply
	if CLIENT and ply == LocalPlayer! and Moonpanel.__focusPrediction
		return Moonpanel.__focusPrediction.time
	ply\GetNW2Float "TheMP FocusTime", 0

Moonpanel.GetFocusAnimationElapsed = (ply = CLIENT and LocalPlayer!) =>
	return 0 unless IsValid ply
	if CLIENT and ply == LocalPlayer! and Moonpanel.__focusPrediction
		return math.max 0, RealTime! - Moonpanel.__focusPrediction.realTime
	focusTime = ply\GetNW2Float "TheMP FocusTime", 0
	math.max 0, CurTime! - focusTime

-------------------------------------------------------
-- Sets whether the player should be focused or not. --
-------------------------------------------------------
Moonpanel.SetFocused = (ply = CLIENT and LocalPlayer!, state) =>
	return unless IsValid ply

    oldState = @IsFocused ply
	Moonpanel.FocusDebugPrint "set-enter", "realm=#{CLIENT and 'client' or 'server'} old=#{tostring(oldState)} new=#{tostring(state)} nw=#{tostring(ply\GetNW2Bool 'TheMP Focused')}"
    if oldState ~= state
        lastFocus = ply\GetNW2Float "TheMP FocusTime", 0

		if state and lastFocus + 0.5 > CurTime!
			Moonpanel.FocusDebugPrint "set-rejected", "cooldown last=#{tostring(lastFocus)}"
			return

		if state
			Moonpanel.PillarFocusAngles[ply] = nil if Moonpanel.PillarFocusAngles
            ply\SetNW2Angle "TheMP FocusAngle", ply\EyeAngles!

        ply\SetNW2Bool "TheMP Focused", state
        ply\SetNW2Float "TheMP FocusTime", CurTime!
		if CLIENT
			Moonpanel.__focusPrediction = {
				state: state
				time: CurTime!
				realTime: RealTime!
				angles: state and ply\EyeAngles! or nil
				deadline: RealTime! + 1.5
				localWritePending: true
			}
		Moonpanel.ApplyFocusPresentation ply, state if CLIENT and
			Moonpanel.ApplyFocusPresentation
		if CLIENT and Moonpanel.__focusPrediction
			Moonpanel.__focusPrediction.localWritePending = false
		Moonpanel.FocusDebugPrint "set-written", "state=#{tostring(state)} nw=#{tostring(ply\GetNW2Bool 'TheMP Focused')} time=#{tostring(ply\GetNW2Float 'TheMP FocusTime')}"
		if SERVER
			if state
				ply\CrosshairDisable!
			else
				Moonpanel\StopControl ply
				Moonpanel.PillarFocusAngles[ply] = nil if Moonpanel.PillarFocusAngles
				ply\CrosshairEnable!

if SERVER
	Moonpanel.ResetPlayerInteraction = (ply) =>
		return unless IsValid(ply) and ply\IsPlayer!
		controlled = ply\GetNW2Entity "TheMP Control"
		if IsValid(controlled) and controlled.Moonpanel and controlled.EndTraceSession
			controlled\EndTraceSession true
		ply\SetNW2Bool "TheMP Focused", false
		ply\SetNW2Angle "TheMP FocusAngle", ply\EyeAngles!
		ply\SetNW2Float "TheMP FocusTime", CurTime! - 1
		ply\SetNW2Entity "TheMP Control", game.GetWorld!
		Moonpanel.PillarFocusAngles[ply] = nil if Moonpanel.PillarFocusAngles
		ply\CrosshairEnable!

	hook.Add "PlayerInitialSpawn", "TheMP Reset Interaction", (ply) ->
		timer.Simple 0, ->
			Moonpanel\ResetPlayerInteraction ply if IsValid ply

	-- Lua autoreload preserves NW2 values. Active traces intentionally do not
	-- survive addon reloads, so clear existing players on the next tick too.
	timer.Simple 0, ->
		for ply in *player.GetAll()
			Moonpanel\ResetPlayerInteraction ply

------------------------------------
-- Handle focus/unfocus requests. --
------------------------------------
hook.Add "KeyPress", "TheMP Focus", (ply, key) ->
	if CLIENT and not IsFirstTimePredicted!
		return
	Moonpanel.FocusDebugPrint "keypress", "key=#{tostring(key)} focused=#{tostring(Moonpanel\IsFocused ply)}"
    if key == IN_USE
		return if IsValid Moonpanel.__focusHolding[ply]

        if Moonpanel\IsFocused ply
			Moonpanel\SetFocused ply, false

        else
			return if not ply\Alive!

            trace = ply\GetEyeTraceNoCursor!
            if trace.Entity and trace.Entity.Moonpanel
				Moonpanel\SetFocused ply, true

--------------------------------------------------------------
-- Handle locking the player camera in place while focused. --
--------------------------------------------------------------
lastClick = 0
actionHeld = false
cancelHeld = false

hook.Add "StartCommand", "TheMP Move", (ply, cmd) ->
	if CLIENT
		commandFocused = Moonpanel\IsFocused ply
		if commandFocused ~= Moonpanel.__focusCommandState
			Moonpanel.FocusDebugPrint "startcommand-state", "cmd=#{tostring(cmd\CommandNumber!)} focused=#{tostring(commandFocused)} nw=#{tostring(ply\GetNW2Bool 'TheMP Focused')}"
			Moonpanel.__focusCommandState = commandFocused
	if Moonpanel\IsFocused ply
		originalButtons = cmd\GetButtons!
		actionDown = cmd\KeyDown(IN_ATTACK) or cmd\KeyDown(IN_JUMP)
		cancelDown = cmd\KeyDown(IN_ATTACK2)
		local cmdActionPressed, cmdCancelPressed
		if CLIENT
			Moonpanel\ApplyControllerTrace ply, cmd if Moonpanel.ApplyControllerTrace
			cmdActionPressed = actionDown and not actionHeld
			cmdCancelPressed = cancelDown and not cancelHeld
			actionHeld = actionDown
			cancelHeld = cancelDown
		elseif cancelDown
			Moonpanel\SetFocused ply, false
		use = (cmd\KeyDown IN_USE) and IN_USE or 0

		cmd\ClearButtons!
		unless Moonpanel.PillarController and
				Moonpanel.PillarController.ProcessCommand and
				Moonpanel.PillarController.ProcessCommand(
					ply, cmd, use, originalButtons)
			cmd\ClearMovement!
			if Moonpanel.__focusMovementLogged ~= true
				Moonpanel.FocusDebugPrint "movement-lock", "cmd=#{tostring(cmd\CommandNumber!)}"
				Moonpanel.__focusMovementLogged = true
			cmd\SetViewAngles Moonpanel\GetFocusAngles ply
			cmd\SetButtons use

		-- Clientside stuff.
		if CLIENT and (input.WasMousePressed(MOUSE_RIGHT) or cmdCancelPressed)
			Moonpanel.FocusDebugPrint "cancel-input", "cmd=#{tostring(cmd\CommandNumber!)}"
			controlled = if Moonpanel.GetPredictedControl
				Moonpanel\GetPredictedControl ply
			else
				ply\GetNW2Entity "TheMP Control"
			Moonpanel.Net.SendTraceAction controlled, 0 if IsValid controlled
			Moonpanel\SetFocused ply, false
			Moonpanel.Net.SendFocusExit!
			return

		actionPressed = CLIENT and (input.WasMousePressed(MOUSE_LEFT) or
			input.WasKeyPressed(KEY_SPACE) or cmdActionPressed)
		if actionPressed
			return if lastClick + 0.05 > CurTime!
			lastClick = CurTime!

			controlled = if Moonpanel.GetPredictedControl
				Moonpanel\GetPredictedControl ply
			else
				ply\GetNW2Entity "TheMP Control"
			if (IsEntity controlled) and IsValid controlled
				Moonpanel\TraceAction controlled

			else
				x, y = input.GetCursorPos!
				aimVec = gui.ScreenToVector x, y

				trace = util.TraceLine
					start: LocalPlayer!\EyePos!
					endpos: LocalPlayer!\EyePos! + aimVec * 4096 * 8
					filter: LocalPlayer!

				if (IsValid trace.Entity) and trace.Entity.Moonpanel
					Moonpanel\RequestControl trace.Entity
	else
		actionHeld = false if CLIENT
		cancelHeld = false if CLIENT
		Moonpanel.__focusMovementLogged = false if CLIENT

hook.Add "CalcMainActivity", "TheMP FocusAnim", (ply) ->
	return if Moonpanel.IsPillarControlling and Moonpanel\IsPillarControlling ply
    ACT_HL2MP_IDLE, -1 if Moonpanel\IsFocused ply

hook.Add "PhysgunDrop", "TheMP Focus Pickup", (ply) ->
	Moonpanel.__focusHolding[ply] = nil

hook.Add "PhysgunPickup", "TheMP Focus Pickup", (ply, ent) ->
	Moonpanel.__focusHolding[ply] = ent

if CLIENT
	WHITE = Color 255, 255, 255, 255

	SOUND_FOCUS_ON = Sound "moonpanel/focus_on.ogg"
	SOUND_FOCUS_OFF = Sound "moonpanel/focus_off.ogg"
	Moonpanel.__focusRenderedStates or= setmetatable {}, __mode: "k"

	Moonpanel.ApplyFocusPresentation = (owner, state) ->
		return unless IsValid owner
		state = state == true
		Moonpanel.FocusDebugPrint "presentation", "state=#{tostring(state)} rendered=#{tostring(Moonpanel.__focusRenderedStates[owner])} nw=#{tostring(owner\GetNW2Bool 'TheMP Focused')}"
		return if Moonpanel.__focusRenderedStates[owner] == state
		Moonpanel.__focusRenderedStates[owner] = state
		if Moonpanel.PillarFocusAngles
			Moonpanel.PillarFocusAngles[owner] = nil
		Moonpanel.FocusDebugPrint "sound-gui", "state=#{tostring(state)}"
		surface.PlaySound state and SOUND_FOCUS_ON or SOUND_FOCUS_OFF
		controlled = Moonpanel.GetPredictedControl and
			Moonpanel\GetPredictedControl owner
		if owner == LocalPlayer!
			if Moonpanel.Net and Moonpanel.Net.SyncClickerState
				Moonpanel.Net.SyncClickerState!
			else
				gui.EnableScreenClicker state and not IsValid controlled

	-- Initialize stuff.
	Moonpanel.InitFocus = =>
		ply = LocalPlayer!
		return false unless IsValid ply
		gui.EnableScreenClicker false
		if Moonpanel.Net and Moonpanel.Net.SyncClickerState
			Moonpanel.Net.SyncClickerState!

		-- Watch the "TheMP Focused" NW2 variable for changes.
		ply\SetNW2VarProxy "TheMP Focused", (owner, _, old, new) ->
			if old ~= new
				return unless IsValid owner
				Moonpanel.FocusDebugPrint "nw2-proxy", "old=#{tostring(old)} new=#{tostring(new)} read=#{tostring(owner\GetNW2Bool 'TheMP Focused')}"
				prediction = Moonpanel.__focusPrediction if owner == LocalPlayer!
				if prediction and not prediction.localWritePending
					if prediction.state == (new == true)
						Moonpanel.FocusDebugPrint "prediction-confirmed", "state=#{tostring(prediction.state)}"
						prediction.acknowledged = true
					else
						Moonpanel.FocusDebugPrint "prediction-rejected", "wanted=#{tostring(prediction.state)} server=#{tostring(new == true)}"
						Moonpanel.__focusPrediction = nil
				Moonpanel.ApplyFocusPresentation owner, new
		true

	---------------------------------------------
	-- Handle the drawing of the focus border. --
	---------------------------------------------
	hook.Add "DrawOverlay", "TheMP Focus Draw", () ->
		-- Surprised the player can be invalid here.
		return unless IsValid LocalPlayer!

		elapsed = Moonpanel\GetFocusAnimationElapsed LocalPlayer!
		time = math.min 1, math.max 0,
			elapsed / Moonpanel.FocusDuration

		focused = Moonpanel\IsFocused!
		if focused ~= Moonpanel.__focusDrawState
			Moonpanel.FocusDebugPrint "border-draw", "focused=#{tostring(focused)} time=#{tostring(time)}"
			Moonpanel.__focusDrawState = focused
		return if time == 1 and not focused

		-- Flip time if unfocusing.
		time = 1 - time if not focused

		-- Get current alpha and multiply it.
		oldAlpha = surface.GetAlphaMultiplier!
		surface.SetAlphaMultiplier oldAlpha * 0.35 * math.EaseInOut time, 0.65, 0.65

		-- Draw 4 rectangles. Nothing to describe here.
		scrh, scrw = ScrH!, ScrW!
		width = math.floor 0.035 * math.min scrh, scrw

		surface.SetDrawColor WHITE
		surface.DrawRect 0, 0, width, scrh
		surface.DrawRect scrw - width, 0, width, scrh
		surface.DrawRect width, 0, scrw - width * 2, width
		surface.DrawRect width, scrh - width, scrw - width * 2, width

		-- Restore alpha.
		surface.SetAlphaMultiplier oldAlpha

	---------------------------------
	-- Handle the view model angle. --
	----------------------------------
	hook.Add "CalcViewModelView", "TheMP ViewModel Angles", (_, _, _, _, pos, ang) ->
		ply = LocalPlayer!
		return unless IsValid ply
		elapsed = Moonpanel\GetFocusAnimationElapsed ply
		time = math.min 1, math.max 0,
			elapsed / Moonpanel.FocusDuration

		focused = Moonpanel\IsFocused ply
		return if time == 1 and not focused

		-- Flip time if unfocusing.
		time = 1 - time if not focused

		-- Adjust the view model angle based on the focusing time.
		ang.p += 8 * math.EaseInOut time, 0.65, 0.65

		-- Return the new pos/ang pair.
		pos, ang

else
	hook.Add "PostPlayerDeath", "TheMP UnFocus", (ply) ->
		if Moonpanel\IsFocused ply
			Moonpanel\SetFocused ply, false
