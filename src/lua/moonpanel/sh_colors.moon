Moonpanel.ColorDefinitions = {
	{ Name: "Black", r: 0, g: 0, b: 0 }
	{ Name: "White", r: 255, g: 255, b: 255 }
	{ Name: "Cyan", r: 0, g: 210, b: 255 }
	{ Name: "Magenta", r: 255, g: 0, b: 210 }
	{ Name: "Yellow", r: 255, g: 230, b: 0 }
	{ Name: "Red", r: 255, g: 64, b: 64 }
	{ Name: "Green", r: 72, g: 220, b: 72 }
	{ Name: "Blue", r: 0, g: 0, b: 255 }
	{ Name: "Orange", r: 255, g: 140, b: 32 }
}

Moonpanel.Color = {definition.Name, id for id, definition in ipairs Moonpanel.ColorDefinitions}
