import sCurve from Moonpanel.render

--
-- Arcane bullshit.
--
travelSpeed = (current, start, finish) ->
	step = (finish - start) / 1

	shift = 0.4

	len = finish - start
	s = ((current - start) / len)

	mod = if (s > 0.5-shift and s < 0.5+shift)
		2
	else
		sign = s < 0.5 and 1 or -1
		(
			1 + -math.cos(
				math.pi * (math.min(current + (len * shift) * sign, finish) - start)/len * 2
			)
		) / 2

	speed = math.min(100, math.max(step * mod * FrameTime!, FrameTime! * 80))

	return speed

class Moonpanel.BranchAnimator
	new: (x, y) =>
		@__nodeStack = {
			{
				:x
				:y
				id: 1
				totalLength: 0
			}
		}

		@__auxiliaryStack = {}

		@__branchNode   = nil
		@__position      = 0
		@__isPathInvalid = true
		@__speedModifier = 1
		@__travelStart   = 0

	pushNode: (x, y) =>
		newNode = {
			:x
			:y
		}

		last = @getLastNode!

		-- Calculate total line length
		newNode.totalLength = if last
			last.totalLength + math.sqrt (x - last.x)^2 + (y - last.y)^2
		else
			0

		-- If the new node is overlapping the first aux node then pop aux,
		firstAux = @__auxiliaryStack[1]
		if not @__branchNode and firstAux and newNode.x == firstAux.x and newNode.y == firstAux.y
			table.remove @__auxiliaryStack, 1
			if #@__auxiliaryStack == 0
				@.__popped = false

		-- otherwise check if we're branching out with @__popped indicating
		-- that there was a pop before the push.
		elseif @__popped
			@__popped = false
			@__branchNode = last.id

		-- Finally, add the new node to the node stack and assign it an ID.
		table.insert @__nodeStack, newNode
		newNode.id = last and last.id + 1 or 1

		return newNode

	popNode: () =>
		last = @getLastNode!
		secondToLast = @__nodeStack[#@__nodeStack - 1]

		if not @__branchNode and @__position >= secondToLast.totalLength
			if not @__auxiliaryStack[1]
				@__longestAuxiliary = last.totalLength

			table.insert @__auxiliaryStack, 1, last
			@.__popped = true

		table.remove @__nodeStack, last.id

		last = @getLastNode!
		if @__branchNode == last.id
			@__branchNode = nil
			@.__popped = true

	bumpCursor: () =>
		@__position = @getLastNode!.totalLength

	getTotalLength: (start = 1) =>
		return @getLastNode!.totalLength

	getBranchNode: () =>
		return @__nodeStack[@__branchNode]

	setSpeedModifier: (value) =>
		@__speedModifier = value

	getAlteredLength: () =>
		length = if @__auxiliaryStack[1]
			@__auxiliaryStack[#@__auxiliaryStack].totalLength
		else
			@__nodeStack[#@__nodeStack].totalLength

		if #@__auxiliaryStack == 0 and #@__nodeStack > 1
			last = @__nodeStack[#@__nodeStack]
			secondToLast = @__nodeStack[#@__nodeStack - 1]
                    
			dx = (1 - (@__cursor or 1)) * (last.x - secondToLast.x)
			dy = (1 - (@__cursor or 1)) * (last.y - secondToLast.y)

			return length - math.sqrt dx^2 + dy^2

		return length

	setCursor: (value) =>
		@__cursor = value

	getLastNode: () =>
		return @__nodeStack[#@__nodeStack]

	getPosition: () =>
		return @__position

	getTravelSpeed: (current, min, max) =>
		return travelSpeed(current, min, max)

	think: () =>
		alteredLength = @getAlteredLength!
		hasAux        = @__auxiliaryStack[1]
		oldPosition   = @__position

		if (hasAux or @__position > alteredLength)
			destination = (@getBranchNode! or @getLastNode!).totalLength

			aux = @__auxiliaryStack[#@__auxiliaryStack - 1]

			if hasAux
				alteredLength = (aux or @getBranchNode! or @getLastNode!).totalLength

			speed = @getTravelSpeed(@__position, destination, @__longestAuxiliary or @__travelStart)
			@__position = math.max @__position - speed * @__speedModifier, alteredLength

			if hasAux and @__position == alteredLength
				if aux
					table.remove @__auxiliaryStack, #@__auxiliaryStack
				else
					@__travelStart = @__position
					@__auxiliaryStack = {}
					@__branchNode = nil

		elseif (@__position < alteredLength)
			if @__branchNode
				@__branchNode = nil

			if @__longestAuxiliary
				@__longestAuxiliary = nil

			speed = @getTravelSpeed(@__position, @__travelStart, alteredLength)
			@__position = math.min @__position + speed * @__speedModifier, alteredLength

		else
			@__travelStart = @__position

		if @__position ~= oldPosition
			return true
