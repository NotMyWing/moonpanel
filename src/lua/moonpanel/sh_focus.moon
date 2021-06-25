AddCSLuaFile!

Moonpanel.FocusDuration = 0.4

Moonpanel.__focusHolding or= {}

------------------------------------------------
-- Gets whether the player is focused or not. --
------------------------------------------------
Moonpanel.IsFocused = (ply = CLIENT and LocalPlayer!) =>
    ply\GetNW2Bool "TheMP Focused"

----------------------------------------------------------------------
-- Gets the focus angle of the player, which gets set automatically --
-- by Moonpanel:SetFocused(ply, state).                             --
----------------------------------------------------------------------
Moonpanel.GetFocusAngles = (ply = CLIENT and LocalPlayer!) =>
    ply\GetNW2Angle "TheMP FocusAngle"

-------------------------------------------------------
-- Sets whether the player should be focused or not. --
-------------------------------------------------------
Moonpanel.SetFocused = (ply = CLIENT and LocalPlayer!, state) =>
	return unless IsValid ply

    oldState = @IsFocused ply
    if oldState ~= state
        lastFocus = ply\GetNW2Float "TheMP FocusTime", 0

        return if lastFocus + 0.5 > CurTime!

        if state
            ply\SetNW2Angle "TheMP FocusAngle", ply\EyeAngles!

        ply\SetNW2Bool "TheMP Focused", state
        ply\SetNW2Float "TheMP FocusTime", CurTime!
		if SERVER
			if state
				ply\CrosshairDisable!
			else
				Moonpanel\StopControl ply
				ply\CrosshairEnable!

------------------------------------
-- Handle focus/unfocus requests. --
------------------------------------
hook.Add "KeyPress", "TheMP Focus", (ply, key) ->
    if key == IN_USE
        return if CLIENT and not IsFirstTimePredicted!
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

hook.Add "StartCommand", "TheMP Move", (ply, cmd) ->
	return if CLIENT and IsFirstTimePredicted!

    if Moonpanel\IsFocused ply
        use = (cmd\KeyDown IN_USE) and IN_USE or 0

        cmd\ClearButtons!
        cmd\SetViewAngles Moonpanel\GetFocusAngles ply
        cmd\SetButtons use

		-- Clientside stuff.
		if CLIENT and input.WasMousePressed MOUSE_LEFT
			return if lastClick + 0.05 > CurTime!
			lastClick = CurTime!

			-- If we're controlling something, tell the server
			-- to stop controlling.
			controlled = ply\GetNW2Entity "TheMP Control"
			if (IsEntity controlled) and IsValid controlled
				Moonpanel\RequestControl controlled

			else
				-- Fire a trace and check whether we're aiming
				-- at a Moonpanel or not.
				x, y = input.GetCursorPos!
				aimVec = gui.ScreenToVector x, y

				trace = util.TraceLine
					start: LocalPlayer!\EyePos!
					endpos: LocalPlayer!\EyePos! + aimVec * 4096 * 8
					filter: LocalPlayer!

				if (IsValid trace.Entity) and trace.Entity.Moonpanel
					Moonpanel\RequestControl trace.Entity

hook.Add "CalcMainActivity", "TheMP FocusAnim", (ply) ->
    ACT_HL2MP_IDLE, -1 if Moonpanel\IsFocused ply

hook.Add "PhysgunDrop", "TheMP Focus Pickup", (ply) ->
	Moonpanel.__focusHolding[ply] = nil

hook.Add "PhysgunPickup", "TheMP Focus Pickup", (ply, ent) ->
	Moonpanel.__focusHolding[ply] = ent

if CLIENT
	WHITE = Color 255, 255, 255, 255

	SOUND_FOCUS_ON = Sound "moonpanel/focus_on.ogg"
	SOUND_FOCUS_OFF = Sound "moonpanel/focus_off.ogg"

	-- Initialize stuff.
	Moonpanel.InitFocus = =>

		-- Watch the "TheMP Focused" NW2 variable for changes.
		LocalPlayer!\SetNW2VarProxy "TheMP Focused", (_, _, old, new) ->
			--return if not game.SinglePlayer! and not IsFirstTimePredicted!

			if old ~= new
				surface.PlaySound new and SOUND_FOCUS_ON or SOUND_FOCUS_OFF
				gui.EnableScreenClicker new

	---------------------------------------------
	-- Handle the drawing of the focus border. --
	---------------------------------------------
	hook.Add "DrawOverlay", "TheMP Focus Draw", () ->
		-- Surprised the player can be invalid here.
		return unless IsValid LocalPlayer!

		time = math.min 1, math.max 0,
			(CurTime! - LocalPlayer!\GetNW2Float "TheMP FocusTime") / Moonpanel.FocusDuration

		focused = Moonpanel\IsFocused!
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
		time = math.min 1, math.max 0,
			(CurTime! - LocalPlayer!\GetNW2Float "TheMP FocusTime") / Moonpanel.FocusDuration

		focused = Moonpanel\IsFocused!
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
