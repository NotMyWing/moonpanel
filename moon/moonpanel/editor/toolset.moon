TOOL_GRAPHICS = {
    ["place"]: (Material "moonpanel/editor_brush.png", "noclamp smooth")
    ["erase"]: (Material "moonpanel/editor_eraser.png", "noclamp smooth")
    ["flood"]: (Material "moonpanel/editor_bucket.png", "noclamp smooth")
}

ENTITY_GRAPHICS = {
    [Moonpanel.EntityTypes.Polyomino]: (Material "moonpanel/polyo.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Sun]: (Material "moonpanel/sun.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Triangle]: (Material "moonpanel/triangle.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Color]: (Material "moonpanel/color.png", "noclamp smooth") 
    [Moonpanel.EntityTypes.Eraser]: (Material "moonpanel/eraser.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Start]: (Material "moonpanel/start.png", "noclamp smooth")
    [Moonpanel.EntityTypes.End]: (Material "moonpanel/end.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Disjoint]: (Material "moonpanel/disjoint.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Hexagon]: {
        (Material "moonpanel/hex_layer1.png", "noclamp smooth")
        (Material "moonpanel/hex_layer2.png", "noclamp smooth")
    }
    [Moonpanel.EntityTypes.Invisible]: {
        [1]: {
            (Material "moonpanel/invisible_layer1.png", "noclamp smooth")
            (Material "moonpanel/invisible_layer2.png", "noclamp smooth")
        }
        [2]: (Material "moonpanel/cell_nocalc.png", "noclamp smooth")
    }
}

class Tool
    new: (@button) =>
    render: (w, h, color) =>
    click: =>
    set: (gridElement, color) =>

-----------------------------------
--                               --
-- Tools.                        --
--                               --
-----------------------------------

toolset_tools = {}

class toolset_tools.Brush extends Tool
    tooltip: "Place or Erase Entities"
    render: (w, h) ->
        innerw = w * 0.8
        innerh = h * 0.8

        surface.SetDrawColor COLOR_WHITE
        surface.SetMaterial TOOL_GRAPHICS["place"]
        surface.DrawTexturedRect (w/2) - (innerw/2), (h/2) - (innerh/2), innerw, innerh

    click: (gridElement, color) ->
        if button and button.tool and button.tool.set
            button.tool.set button, gridElement, color
            return true