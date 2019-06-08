return class Tile
    render: () =>
        if not @config
            return

        if @backgroundNeedsRendering
            @backgroundNeedsRendering = false
            print "Re-rendering the background"
            render.selectRenderTarget "background"
            render.setColor @colors.background
            render.drawRect 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT
            render.selectRenderTarget nil

        @toggleTime or= timer.systime!
        timespan = math.min timer.systime! - @toggleTime, 1
        if @isPowered and timespan <= 1
                render.setColor Color 0, 0, 0, 255 * 1 - (timespan / 2)
        elseif not @isPowered
            render.setColor Color 0, 0, 0, 255 * (timespan / 2)
            if timespan >= 2
                return

        render.setColor Color 255, 255, 255
        render.clear!
        render.setRenderTargetTexture "background"
        render.drawTexturedRectFast 0, 0, 1024, 1024
        render.setTexture!

    initNetHooks: () =>
        net.receive "UpdatePowered", () ->
            @isPowered = (net.readInt 1) == 1 and true or false

        net.receive "InitializeTileConfig", () ->
            print "Received data, reading..."
            length = net.readInt 32
            data = json.decode fastlz.decompress net.readData length

            @receiveConfig data

    receiveConfig: (config) =>
        @colors = config.colors
        
        -- Hackity hack
        for k, v in pairs @colors
            @colors[k] = Color v.r, v.g, v.b, v.a

        @penColor = @colors.traced
        @config = config
        @backgroundNeedsRendering = true

    new: () =>
        render.createRenderTarget "background"
        hook.add "render", "render", () ->
            @render!
        @initNetHooks!