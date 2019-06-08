if CLIENT
    needsRedraw = true
    render.createRenderTarget "test"
    hook.add "render", "", () ->
        if needsRedraw
            needsRedraw = false
            render.selectRenderTarget "test"
            render.setColor Color 160, 20, 20

            for i = 0, 128
                for j = 0, 128
                    render.drawRect 0.5 + (i * 4), 0.5 + (j * 4), 2, 2

        render.selectRenderTarget nil
        render.clear!
        render.setRenderTargetTexture "test"
        render.drawTexturedRect 0, 0, 1024, 1024
        render.setColor Color 0, 255, 0
        
        deg = timer.systime!
        x = 256 + (math.cos deg) * 128
        y = 256 + (math.sin deg) * 128

        render.drawRectFast x - 32, y - 32, 64, 64
        