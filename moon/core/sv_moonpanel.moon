return class Tile
    initializeTileConfig: (config) =>
        -- Init coloures
        config.colors            or= {}
        config.colors.background or= COLOR_BG
        config.colors.untraced   or= COLOR_UNTRACED
        config.colors.traced     or= COLOR_TRACED
        config.colors.vignette   or= COLOR_VIGNETTE

        -- Init tile defaults
        config.tile        or= {}
        config.tile.width  or= 4
        config.tile.height or= 4

        width  = config.tile.width
        height = config.tile.height

        -- Calculate dimensions
        innerZoneLength = math.ceil SCREEN_WIDTH * DEFAULT_SCREEN_TO_INNER_RATIO
        
        maxDim    = math.max width, height
        barWidth  = config.tile.barWidth or (math.max MINIMUM_BARWIDTH, (innerZoneLength / maxDim * DEFAULT_CEIL_TO_BAR_RATIO))
        barLength = (innerZoneLength - (barWidth * (maxDim + 1))) / maxDim
        
        @dimensions.offsetH = (SCREEN_WIDTH - (barWidth * (width + 1)) - (barLength * width)) / 2
        @dimensions.offsetV = (SCREEN_WIDTH - (barWidth * (height + 1)) - (barLength * height)) / 2

        @dimensions.innerZoneLength = innerZoneLength
        @dimensions.barWidth = barWidth
        @dimensions.barLength = barLength
        @dimensions.width = width
        @dimensions.height = height

        if SERVER
            data = fastlz.compress json.encode config

            -- This really shouldn't be happening...
            timer.simple 2, () ->
                net.start "InitializeTileConfig"
                net.writeInt #data, 32
                net.writeData data, #data
                net.send!
    new: (@config) =>
        print "Serverside init"
        @initializeTileConfig @config