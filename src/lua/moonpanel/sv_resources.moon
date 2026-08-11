-- Register every client-facing asset present in the mounted addon tree.
-- This deliberately runs on the server only. Lua is transferred through
-- AddCSLuaFile; materials and sounds use the resource download system.
if SERVER
	add = (directory) ->
		files, directories = file.Find directory .. "/*", "GAME"
		return unless files or directories

		for name in *(files or {})
			resource.AddSingleFile directory .. "/" .. name

		for name in *(directories or {})
			add directory .. "/" .. name

	add "materials/moonpanel"
	add "sound/moonpanel"
	resource.AddSingleFile "shaders/fxc/moonpanel_display_v3_ps20b.vcs"
	resource.AddSingleFile "shaders/fxc/moonpanel_display_v3_vs20.vcs"
