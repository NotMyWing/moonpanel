intersection = {}

corner = Material "moonpanel/editor/corner128/0.png", "noclamp smooth mips"

white = Color 255, 255, 255
types = Moonpanel.EntityTypes
hexagon = Material "moonpanel/common/hexagon.png"
hexagon_hollow = Material "moonpanel/common/hexagon_hollow.png"

intersection.Init = () =>
    @type = Moonpanel.ObjectTypes.Intersection

trunc = Moonpanel.trunc
unitVector = (angle) ->
    angle = math.rad angle + 90
    x = trunc (math.cos angle), 3
    y = trunc (math.sin angle), 3

    return { :x, :y }

intersection.getAngle = (x, y) =>
    invis = Moonpanel.EntityTypes.Invisible

    left   = @getLeft!
    right  = @getRight!
    top    = @getTop!
    bottom = @getBottom!

    left   = left   and not (left.entity   and left.entity   == invis) and left
    right  = right  and not (right.entity  and right.entity  == invis) and right
    top    = top    and not (top.entity    and top.entity    == invis) and top
    bottom = bottom and not (bottom.entity and bottom.entity == invis) and bottom

    rowx, rowy = @GetParent!\GetPos!
    localx, localy, w, h = @GetBounds! 
    x = rowx + localx + w / 2
    y = rowy + localy + h / 2

    isLeftMost = x <= @panel.calculatedDimensions.screenWidth / 2
    isTopMost  = y <= @panel.calculatedDimensions.screenHeight / 2

    numNeighbours = (left and 1 or 0) +
        (right and 1 or 0) +
        (top and 1 or 0) +
        (bottom and 1 or 0)

    if numNeighbours == 3
        if not top
            return 180

        if not bottom
            return 0

        if not left
            return 90

        if not right
            return 270

        return false

    if numNeighbours == 2
        if top and right
            return 45

        if bottom and right
            return 135

        if left and bottom
            return 225

        if left and top
            return 315

        if left and right
            return isTopMost and 180 or 0

        if top and bottom
            return isLeftMost and 90 or 270

    if numNeighbours == 1
        if bottom
            return 180

        if top
            return 0

        if right
            return 270

        if left
            return 90

    return false

EMPTY_TABLE = {}

intersection.getLeft = =>
    @cachedLeft or= (@panel.hpaths[@j] or EMPTY_TABLE)[@i - 1]
    return @cachedLeft

intersection.getRight = =>
    @cachedRight or= (@panel.hpaths[@j] or EMPTY_TABLE)[@i]
    return @cachedRight

intersection.getTop = =>
    @cachedTop or= (@panel.vpaths[@j - 1] or EMPTY_TABLE)[@i]
    return @cachedTop

intersection.getBottom = =>
    @cachedBottom or= (@panel.vpaths[@j] or EMPTY_TABLE)[@i]
    return @cachedBottom

intersection.Paint = (w, h) =>
    if @entity == Moonpanel.EntityTypes.Invisible
        return
        
    draw.NoTexture!
    surface.SetDrawColor @panel.data.colors.untraced or Moonpanel.DefaultColors.Untraced

    render.PushFilterMag TEXFILTER.ANISOTROPIC
    render.PushFilterMin TEXFILTER.ANISOTROPIC
    
    barCircle = @panel.calculatedDimensions.barCircle
    startCircle = @panel.calculatedDimensions.startCircle
    if startCircle and @entity == Moonpanel.EntityTypes.Start
        surface.DisableClipping true
        Moonpanel.render.drawCircleAt startCircle, w/2, w/2
        surface.DisableClipping false
    
    elseif @entity == Moonpanel.EntityTypes.End
        angle = @getAngle!

        surface.DrawRect 0, 0, w, h

        if angle
            surface.DisableClipping true

            do
                matrix = Matrix!
                gx, gy = @LocalToScreen 0, 0
                w05 = math.ceil w / 2

                gv = Vector gx + w05, gy + w05, 0 
                matrix\Translate gv
                matrix\Rotate Angle 0, angle, 0
                matrix\Translate -gv

                w15 = math.ceil w * 1.5

                matrix\Translate Vector w/2, w15, 0 

                cam.PushModelMatrix matrix
                barCircle!

                surface.DrawRect -w05, -w15, w, w15
                cam.PopModelMatrix!

            surface.DisableClipping false
        else
            @entity = nil

    else
        if not @corner
            surface.DrawRect 0, 0, w, h

        else
            surface.SetMaterial corner
            surface.DrawTexturedRectRotated math.floor(w/2), math.floor(h/2), w + 1, h + 1, (@corner - 1) * 90

        if @entity == types.Hexagon      
            innerw = math.min w, h
            innerh = innerw

            surface.SetDrawColor Moonpanel.Colors[@attributes.color or Moonpanel.Color.Black]
            surface.SetMaterial @attributes.hollow and hexagon_hollow or hexagon
            surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

    render.PopFilterMag!
    render.PopFilterMin!

return vgui.RegisterTable intersection, "DButton"  