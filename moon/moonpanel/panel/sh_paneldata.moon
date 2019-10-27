import sanitizeColor from Moonpanel

class PanelData
    new: ->
    readFromJSON: (jsonString) ->
        input = util.JSONToTable jsonString
        if not input
            error "Malformed json file"

        @__rawData = input

        input_tile = input.Tile or {}
        input_dimensions = input.Dimensions or {}

        newData = {
            title:    input_tile.Title
            w:        input_tile.Width    or 3
            h:        input_tile.Height   or 3
            symmetry: input_tile.Symmetry or 0
            
            barWidth:         0
            innerScreenRatio: 0
            maxBarLength:     0
            disjointLength:   0

            colors: {}
            
            cells: {}
            intersections: {}
            vpaths:        {}
            hpaths:        {}
        }

        input_colors = input.Colors or {}
        newData.colors.background = sanitizeColor input_colors.Background , Moonpanel.DefaultColors.Background
        newData.colors.vignette   = sanitizeColor input_colors.Vignette   , Moonpanel.DefaultColors.Vignette
        newData.colors.cell       = sanitizeColor input_colors.Cell       , Moonpanel.DefaultColors.Cell
        newData.colors.traced     = sanitizeColor input_colors.Traced     , Moonpanel.DefaultColors.Traced
        newData.colors.untraced   = sanitizeColor input_colors.Untraced   , Moonpanel.DefaultColors.Untraced
        newData.colors.finished   = sanitizeColor input_colors.Finished   , Moonpanel.DefaultColors.Finished
        newData.colors.errored    = sanitizeColor input_colors.Errored    , Moonpanel.DefaultColors.Errored

    writeToJSON: ->

class GridPanelData extends PanelData
    readFromJSON: (jsonString) ->
        super jsonString

        w, h = newData.w, newData.h
        for j = 1, h + 1
            for i = 1, w + 1
                si, sj = i, j

                if input.Cells and j <= h and i <= w and input.Cells[sj] and input.Cells[sj][si]
                    cell = input.Cells[sj][si]

                if input.HPaths and i <= w and input.HPaths[sj] and input.HPaths[sj][si]
                    hbar = input.HPaths[sj][si]

                if input.VPaths and j <= h and input.VPaths[sj] and input.VPaths[sj][si]
                    vbar = input.VPaths[sj][si]

                if input.Intersections and input.Intersections[sj] and input.Intersections[sj][si]
                    int = input.Intersections[sj][si]
