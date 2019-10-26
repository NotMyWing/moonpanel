windmillBrowser = {}

windmillBrowser.Init = () =>
    with @
        \SetWide ScrW! * 0.6
        \SetTall ScrH! * 0.7
        \SetTitle "The Moonpanel - The Windmill Browser"
        \SetDeleteOnClose false
        \DockPadding 0, 24, 0, 0
        \SetDraggable true
        \Center!
        \SetSizable true

    with @__navBar = vgui.CreateFromTable (include "moonpanel/editor/vgui_dhtmlcontrols.lua"), @
        \Dock TOP
        .ImportCallback = (data) ->
            if @ImportCallback
                @.ImportCallback data

    hrefCallback = (newHref) ->
        @__navBar\UpdateHistory newHref
        @__navBar.AddressBar\SetText newHref

    with @__html = vgui.Create "DHTML", @
        \Dock FILL 
        \DockMargin 4, 4, 4, 4
        \OpenURL "https://windmill.thefifthmatt.com/"
        .OnFinishLoadingDocument = ->
            \AddFunction "themp", "hrefCallback", hrefCallback
            \Call [[
                var oldHref = null;
                setInterval(function () {
	                if (window.location.href != oldHref) {
                        themp.hrefCallback(window.location.href);
                        oldHref = window.location.href;
                    }
                }, 500);
            ]]


    @__navBar\SetHTML @__html

return vgui.RegisterTable windmillBrowser, "DFrame"