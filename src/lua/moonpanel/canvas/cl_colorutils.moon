ColorUtils = {}

ColorUtils.Rgb2Xyz = (sR, sG, sB) ->
	if sR > 0.04045
		sR = ((sR + 0.055) / 1.055) ^ 2.4
	else
		sR = sR / 12.92

	if sG > 0.04045
		sG = ((sG + 0.055) / 1.055) ^ 2.4
	else
		sG = sG / 12.92

	if sB > 0.04045
		sB = ((sB + 0.055) / 1.055) ^ 2.4
	else
		sB = sB / 12.92

	x = sR * 0.4124 + sG * 0.3576 + sB * 0.1805
	y = sR * 0.2126 + sG * 0.7152 + sB * 0.0722
	z = sR * 0.0193 + sG * 0.1192 + sB * 0.9505

	x * 100, y * 100, z * 100

ColorUtils.Xyz2Rgb = (x, y, z) ->
	x /= 100
	y /= 100
	z /= 100

	r = x *  3.2406 + y * -1.5372 + z * -0.4986
	g = x * -0.9689 + y *  1.8758 + z *  0.0415
	b = x *  0.0557 + y * -0.2040 + z *  1.0570

	if r > 0.0031308
		r = 1.055 * (r ^ (1 / 2.4)) - 0.055
	else
		r = 12.92 * r

	if g > 0.0031308
		g = 1.055 * (g ^ (1 / 2.4)) - 0.055
	else
		g = 12.92 * g

	if b > 0.0031308
		b = 1.055 * (b ^ (1 / 2.4)) - 0.055
	else
		b = 12.92 * b

	r, g, b

ColorUtils.Xyz2Lab = (x, y, z) ->
	x /= 95.047
	y /= 100
	z /= 108.883

	if x > 0.008856
		x = x ^ (1/3)
	else
		x = (7.787 * x) + (16 / 116)

	if y > 0.008856
		y = y ^ (1/3)
	else
		y = (7.787 * y) + (16 / 116)

	if z > 0.008856
		z = z ^ ( 1/3 )
	else
		z = (7.787 * z) + (16 / 116)

	l = (116 * y) - 16
	a = 500 * (x - y)
	b = 200 * (y - z)

	l, a, b

ColorUtils.Lab2Xyz = (l, a, b) ->
	y = (l + 16) / 116
	x = a / 500 + y
	z = y - b / 200

	if y^3 > 0.008856
		y = y^3
	else
		y = (y - 16 / 116) / 7.787

	if x^3 > 0.008856
		x = x^3
	else
		x = (x - 16 / 116) / 7.787

	if z^3 > 0.008856
		z = z^3
	else
		z = (z - 16 / 116) / 7.787

	x *= 95.047
	y *= 100
	z *= 108.883

	x, y, z

ColorUtils.Lab2Lch = (l, a, b) ->
	h = math.atan2 b, a

	if h > 0
		h = (h / math.pi) * 180
	else
		h = 360 - (math.abs(h) / math.pi) * 180

	c = math.sqrt a^2 + b^2

	l, c, h

ColorUtils.Lch2Lab = (l, c, h) ->
	hr = math.rad h

	a = math.cos(hr) * c
	b = math.sin(hr) * c

	l, a, b

lab2lch = ColorUtils.Lab2Lch
xyz2lab = ColorUtils.Xyz2Lab
rgb2xyz = ColorUtils.Rgb2Xyz
xyz2rgb = ColorUtils.Xyz2Rgb
lab2xyz = ColorUtils.Lab2Xyz
lch2lab = ColorUtils.Lch2Lab

ColorUtils.Rgb2Lch = (r, g, b) -> lab2lch xyz2lab rgb2xyz r, g, b
ColorUtils.Lch2Rgb = (l, c, h) -> xyz2rgb lab2xyz lch2lab l, c, h

concommand.Add "cinterp_tests", ->
	with vgui.Create "DFrame"
		\SetTitle "Interps"
		\SetSize 600, 265
		\MakePopup!
		\Center!

		funcs = {
			["RGB"]: (cA, cB, value) ->
				invValue = 1 - value

				r = math.Round cA.r * invValue + cB.r * value
				g = math.Round cA.g * invValue + cB.g * value
				b = math.Round cA.b * invValue + cB.b * value

				r, g, b

			["HSV"]: (cA, cB, value) ->
				invValue = 1 - value

				cA = { ColorToHSV cA }
				cB = { ColorToHSV cB }

				h = cA[1] * invValue + cB[1] * value
				s = cA[2] * invValue + cB[2] * value
				v = cA[3] * invValue + cB[3] * value

				color = HSVToColor h, s, v

				color.r, color.g, color.b

			["LCH"]: (cA, cB, value) ->
				invValue = 1 - value

				cA = { ColorUtils.Rgb2Lch cA.r, cA.g, cA.b }
				cB = { ColorUtils.Rgb2Lch cB.r, cB.g, cB.b }

				cA[1] = cA[1] * invValue + cB[1] * value
				cA[2] = cA[2] * invValue + cB[2] * value
				cA[3] = cA[3] * invValue + cB[3] * value

				ColorUtils.Lch2Rgb cA[1], cA[2], cA[3]
		}

		startColor = Color 20, 80, 170
		endColor = Color 226, 146, 10
		steps = 1024

		for name, func in pairs funcs
			with \Add "Panel"
				\Dock TOP
				\SetTall 70
				\DockMargin 0, 0, 0, 10

				with \Add "DLabel"
					\Dock TOP
					\SetText " " .. name

				with \Add "DPanel"
					\Dock LEFT
					\SetBackgroundColor Color 64, 64, 64
					\DockPadding 2, 2, 2, 2
					\InvalidateParent true
					\SetWide \GetTall!

					with \Add "DPanel"
						\Dock FILL
						\SetBackgroundColor startColor

				with \Add "DPanel"
					\Dock RIGHT
					\SetBackgroundColor Color 64, 64, 64
					\DockPadding 2, 2, 2, 2
					\InvalidateParent true
					\SetWide \GetTall!

					with \Add "DPanel"
						\Dock FILL
						\SetBackgroundColor endColor

				with \Add "DPanel"
					\SetBackgroundColor Color 64, 64, 64
					\DockMargin 2, 0, 2, 0
					\DockPadding 2, 2, 2, 2
					\Dock FILL

					with \Add "Panel"
						\Dock FILL

						.Paint = (_, w, h) ->
							stepSize = w / steps

							for i = 0, steps
								step = i / steps
								r, g, b = func startColor, endColor, step
								surface.SetDrawColor r, g, b
								surface.DrawRect (i - 1) * stepSize, 0, stepSize + 1, h

return ColorUtils
