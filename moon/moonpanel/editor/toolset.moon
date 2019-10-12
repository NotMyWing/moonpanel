TOOL_GRAPHICS = {
    ["place"]: (Material "moonpanel/editor_brush.png", "noclamp smooth")
    ["erase"]: (Material "moonpanel/editor_eraser.png", "noclamp smooth")
    ["flood"]: (Material "moonpanel/editor_bucket.png", "noclamp smooth")
}

ENTITY_GRAPHICS = {
    [Moonpanel.EntityTypes.Polyomino]: (Material "moonpanel/editor/polyo.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Sun]: (Material "moonpanel/common/sun.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Triangle]: (Material "moonpanel/common/triangle.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Color]: (Material "moonpanel/common/color.png", "noclamp smooth") 
    [Moonpanel.EntityTypes.Eraser]: (Material "moonpanel/common/eraser.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Start]: (Material "moonpanel/editor/start.png", "noclamp smooth")
    [Moonpanel.EntityTypes.End]: (Material "moonpanel/editor/end.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Disjoint]: (Material "moonpanel/editor/disjoint.png", "noclamp smooth")
    [Moonpanel.EntityTypes.Hexagon]: {
        (Material "moonpanel/editor/hex_layer1.png", "noclamp smooth")
        (Material "moonpanel/editor/hex_layer2.png", "noclamp smooth")
    }
    [Moonpanel.EntityTypes.Invisible]: {
        [1]: {
            (Material "moonpanel/editor/invisible_layer1.png", "noclamp smooth")
            (Material "moonpanel/editor/invisible_layer2.png", "noclamp smooth")
        }
        [2]: (Material "moonpanel/editor/cell_nocalc.png", "noclamp smooth")
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