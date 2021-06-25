class Moonpanel.Canvas.Animator
	new: =>
		@__animations = {}

	Think: =>
		index = 1
		while @__animations[index]
			if SysTime! >= @__animations[index].endTime
				@__animations[index].callback!
				table.remove @__animations, index
			else
				index += 1

	ClearAnimations: =>
		@__animations = {}

	NewAnimation: (length, delay = 0, ease = -1, callback) =>
		table.insert @__animations, {
			:length
			:delay
			:ease
			:callback

			endTime: SysTime! + length + delay
		}

		{
			EndTime: SysTime! + length + delay
			StartTime: SysTime! + delay
			Ease: ease
			OnEnd: callback
		}
