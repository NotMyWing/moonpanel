AddCSLuaFile!

if CLIENT
	Moonpanel.InitControl = =>
		-- Watch the "TheMP Control" NW2 variable for changes.
		LocalPlayer!\SetNW2VarProxy "TheMP Control", (_, _, old, new) ->
			if old ~= new and Moonpanel\IsFocused!
				gui.EnableScreenClicker not IsValid new

	------------------------------------------------------------
	-- Dispatches PanelRequestControl requests to the server. --
	------------------------------------------------------------
	Moonpanel.RequestControl = (entity) =>
		ply = LocalPlayer!
		controlled = ply\GetNW2Entity "TheMP Control"

		ply\SetNW2Entity "TheMP Control", game.GetWorld! if (IsEntity controlled) and IsValid controlled

		x, y = entity\GetCursorPos!
		Moonpanel.Net.PanelRequestControl entity, x, y

	hook.Add "InputMouseApply", "TheMP Control", (cmd, x, y) ->
		if Moonpanel\ApplyDeltas LocalPlayer!, x, y
			cmd\SetMouseX 0
			cmd\SetMouseY 0
			true

else
	--------------------------------------------------------
	-- Acknowledges panel control requests and associates --
	-- players with panels.                               --
	--------------------------------------------------------
	Moonpanel.RequestControl = (ply, entity, x, y) =>
		controlled = ply\GetNW2Entity "TheMP Control"

		if (IsEntity controlled) and IsValid controlled
			Moonpanel\StopControl ply

		elseif (IsEntity entity) and IsValid entity
			if entity.Moonpanel and entity.RequestControl and entity\RequestControl ply, x, y
				ply\SetNW2Entity "TheMP Control", entity

	----------------------------------------------
	-- Acknowledges panel stopcontrol requests. --
	----------------------------------------------
	Moonpanel.StopControl = (ply) =>
		controlled = ply\GetNW2Entity "TheMP Control"
		if (IsEntity controlled) and IsValid controlled
			controlled\StopControl!
			ply\SetNW2Entity "TheMP Control", game.GetWorld!

-------------------------------------------------------------
-- Applies panel deltas to the currently controlled panel. --
-- Does nothing if the player isn't controlling anything.  --
-------------------------------------------------------------
Moonpanel.ApplyDeltas = (ply, dX = 0, dY = 0) =>
	return if dX == 0 and dY == 0

	controlled = ply\GetNW2Entity "TheMP Control"
	if ((IsEntity controlled) and IsValid controlled)
		dX = math.Clamp dX, -127, 127
		dY = math.Clamp dY, -127, 127

		if controlled\GetController! == ply and controlled\ApplyDeltas ply, dX, dY
			Moonpanel.Net.SendDeltas dX, dY if CLIENT

			true
