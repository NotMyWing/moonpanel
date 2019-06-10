--@include moonpanel/core/sh_moonpanel.txt

getters = (cls, getters) ->
  cls.__base.__index = (key) =>
    if getter = getters[key]
      getter @
    else
      cls.__base[key]

setters = (cls, setters) ->
  cls.__base.__newindex = (key, val) =>
    if setter = setters[key]
      setter @, val
    else
      rawset @, key, val

TileShared = require "moonpanel/core/sh_moonpanel.txt"

COLOR_BG = Color 80, 77, 255, 255
COLOR_UNTRACED = Color 40, 22, 186
COLOR_TRACED = Color 255, 255, 255, 255
COLOR_VIGNETTE = Color 0, 0, 0, 92

DEFAULT_RESOLUTIONS = {
    {
        innerScreenRatio: 0.4
        barWidth: 40
    }
    {
        innerScreenRatio: 0.5
        barWidth: 35
    }
    {
        innerScreenRatio: 0.6
        barWidth: 30
    }
    {
        innerScreenRatio: 0.7
        barWidth: 25
    }
    {
        innerScreenRatio: 0.8
        barWidth: 25
    }
    {
        innerScreenRatio: 0.85
        barWidth: 22
    }
    {
        innerScreenRatio: 0.875
        barWidth: 20
    }
    {
        innerScreenRatio: 0.875
        barWidth: 18
    }
    {
        innerScreenRatio: 0.875
        barWidth: 17
    }
    {
        innerScreenRatio: 0.875
        barWidth: 15
    }
}

DEFAULTEST_RESOLUTION = {
    innerScreenRatio: 0.875
    barWidth: 12
}

return class Tile extends TileShared
    __internal: {}
    getters @,
        isPowered: =>
            return @__internal.isPowered
    
    setters @,
        isPowered: (value) =>
            @__internal.isPowered = true
            net.start "UpdatePowered"
            net.writeInt value and 1 or 0, 2
            net.send!

    setup: (@tileData) =>
        -- Init coloures
        @tileData.colors            or= {}
        @tileData.colors.background or= COLOR_BG
        @tileData.colors.untraced   or= COLOR_UNTRACED
        @tileData.colors.traced     or= COLOR_TRACED
        @tileData.colors.vignette   or= COLOR_VIGNETTE

        -- Init tile defaults
        @tileData.tile        or= {}
        @tileData.tile.width  or= 2
        @tileData.tile.height or= 2

        width  = @tileData.tile.width
        height = @tileData.tile.height

        screenWidth = 1024 -- why? because for some reason RT contexts are 1024.
        -- it's also good to keep in mind that tileData.dimensions.screenWidth
        -- should only be used for rendering in RT context.

        -- Calculate dimensions        
        maxDim          = math.max width, height
        resolution      = DEFAULT_RESOLUTIONS[maxDim] or DEFAULTEST_RESOLUTION
        print maxDim
        printTable DEFAULT_RESOLUTIONS
        barWidth        = resolution.barWidth

        innerZoneLength = math.ceil screenWidth * resolution.innerScreenRatio

        barLength       = math.floor (innerZoneLength - (barWidth * (maxDim + 1))) / maxDim

        tileData.dimensions = {
            offsetH: math.ceil (screenWidth - (barWidth * (width + 1)) - (barLength * width)) / 2
            offsetV: math.ceil (screenWidth - (barWidth * (height + 1)) - (barLength * height)) / 2

            innerZoneLength: innerZoneLength
            barWidth: barWidth
            barLength: barLength
            width: width
            height: height

            screenWidth: screenWidth
            screenHeight: screenWidth
        }

        data = fastlz.compress json.encode @tileData

        net.start "ClearTileData"
        net.send!

        sendData = () ->
            net.start "UpdateTileData"
            net.writeInt #data, 32
            net.writeData data, #data
            net.send!
            @isPowered = true

        -- Starfall bug
        if @firstExecution
            @firstExecution = false
            timer.simple 2, sendData
        else
            sendData!

    new: () =>
        @firstExecution = true
        super!