-- ==============================================================================
-- ZAPHSHELL HYPRLAND LUA CONFIGURATION MODULE
-- Include this file in your main hyprland.lua:
--   dofile(os.getenv("HOME") .. "/.config/hypr/quickshell.lua")
-- ==============================================================================

local mainMod = "SUPER"
local home = os.getenv("HOME") or ""
local qsScript = home .. "/.config/quickshell/scripts/"

-- Unbind any conflicting default/existing binding on the same shortcut before registering ours
local function rebind(combo, dsp, opts)
    pcall(hl.unbind, combo)
    local lowered = combo:gsub("(%+ )([A-Z])$", function(prefix, ch)
        return prefix .. ch:lower()
    end)
    if lowered ~= combo then
        pcall(hl.unbind, lowered)
    end
    if opts ~= nil then
        return hl.bind(combo, dsp, opts)
    end
    return hl.bind(combo, dsp)
end

-- ------------------------------------------------------------------------------
-- 1. AUTOSTART & APPEARANCE
-- ------------------------------------------------------------------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("quickshell --no-duplicate")
    hl.exec_cmd("wl-paste --type text --watch " .. qsScript .. "clipboard.sh record")
    hl.exec_cmd("wl-paste --type image --watch " .. qsScript .. "clipboard.sh record")
end)

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        background_color        = 0x121316,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,
    },
    general = {
        gaps_in  = 5,
        gaps_out = { top = 10, right = 12, bottom = 12, left = 12 },
        border_size = 1,
        col = {
            active_border   = { colors = {"rgba(ffffff4c)", "rgba(ffffff1c)"}, angle = 45 },
            inactive_border = "rgba(ffffff0e)",
        },
    },
    decoration = {
        rounding = 24,
        shadow = {
            enabled        = true,
            range          = 8,
            render_power   = 3,
            color          = 0x0effffff,
            color_inactive = 0x12000000,
        },
    },
})

-- ------------------------------------------------------------------------------
-- 2. WORKSPACE NAVIGATION & MANAGEMENT
-- ------------------------------------------------------------------------------
for i = 1, 10 do
    local key = i % 10
    -- Switch workspace
    rebind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    -- Switch workspace group (group 0/1 = 1-10, group 2 = 11-20, etc.)
    rebind("CTRL + " .. mainMod .. " + " .. key, hl.dsp.focus({ workspace = (i == 10 and 10 or i) * 10 - 9 }))
    -- Move window to workspace
    rebind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i }))
    -- Move window to workspace silently
    rebind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, silent = true }))
    -- Move window to workspace group
    rebind("CTRL + " .. mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = (i == 10 and 10 or i) * 10 - 9 }))
end

-- Next Workspace
rebind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
rebind("CTRL + " .. mainMod .. " + right", hl.dsp.focus({ workspace = "e+1" }))
rebind(mainMod .. " + Next", hl.dsp.focus({ workspace = "e+1" }))

-- Previous Workspace
rebind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
rebind("CTRL + " .. mainMod .. " + left", hl.dsp.focus({ workspace = "e-1" }))
rebind(mainMod .. " + Prior", hl.dsp.focus({ workspace = "e-1" }))

-- Next Workspace Group
rebind("CTRL + " .. mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "+10" }))
-- Previous Workspace Group
rebind("CTRL + " .. mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "-10" }))

-- Move Window to Next / Prev Workspace
rebind(mainMod .. " + ALT + mouse_down", hl.dsp.window.move({ workspace = "e+1" }))
rebind(mainMod .. " + ALT + Next", hl.dsp.window.move({ workspace = "e+1" }))
rebind("CTRL + " .. mainMod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }))

rebind(mainMod .. " + ALT + mouse_up", hl.dsp.window.move({ workspace = "e-1" }))
rebind(mainMod .. " + ALT + Prior", hl.dsp.window.move({ workspace = "e-1" }))
rebind("CTRL + " .. mainMod .. " + SHIFT + left", hl.dsp.window.move({ workspace = "e-1" }))

-- Move Window to / from Special Workspace
rebind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))
rebind("CTRL + " .. mainMod .. " + SHIFT + up", hl.dsp.window.move({ workspace = "special:magic" }))
rebind("CTRL + " .. mainMod .. " + SHIFT + down", hl.dsp.window.move({ workspace = "e" }))

-- Show / Hide Desktop (Win+D style single-hand toggle)
rebind(mainMod .. " + A", hl.dsp.exec_cmd(qsScript .. "show-desktop.sh"))

-- ------------------------------------------------------------------------------
-- 3. SPECIAL WORKSPACES (SCRATCHPADS)
-- ------------------------------------------------------------------------------
rebind(mainMod .. " + S", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh magic"))
rebind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh sysmon"))
rebind(mainMod .. " + M", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh music"))
rebind(mainMod .. " + D", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh comm"))

-- ------------------------------------------------------------------------------
-- 4. WINDOW ACTIONS & SIZING
-- ------------------------------------------------------------------------------
rebind(mainMod .. " + Q", hl.dsp.window.close())
rebind(mainMod .. " + ALT + SPACE", hl.dsp.window.float({ action = "toggle" }))
rebind(mainMod .. " + F", hl.dsp.window.fullscreen())
rebind(mainMod .. " + ALT + F", hl.dsp.exec_raw("fullscreen 1"))
rebind(mainMod .. " + ALT + backslash", hl.dsp.exec_raw("setfloating; pin; resizeactive exact 480 270"))
rebind(mainMod .. " + P", hl.dsp.window.pin())
rebind(mainMod .. " + Z", hl.dsp.exec_raw("submap move"))
rebind(mainMod .. " + X", hl.dsp.exec_raw("submap resize"))
rebind("CTRL + " .. mainMod .. " + backslash", hl.dsp.exec_raw("centerwindow"))
rebind("CTRL + " .. mainMod .. " + ALT + backslash", hl.dsp.exec_raw("resizeactive exact 50% 50%; centerwindow"))

-- Incremental width/height adjustments
rebind(mainMod .. " + minus", hl.dsp.exec_raw("resizeactive -40 0"), { repeating = true })
rebind(mainMod .. " + ALT + left", hl.dsp.exec_raw("resizeactive -40 0"), { repeating = true })
rebind(mainMod .. " + equal", hl.dsp.exec_raw("resizeactive 40 0"), { repeating = true })
rebind(mainMod .. " + ALT + right", hl.dsp.exec_raw("resizeactive 40 0"), { repeating = true })
rebind(mainMod .. " + SHIFT + minus", hl.dsp.exec_raw("resizeactive 0 -40"), { repeating = true })
rebind(mainMod .. " + ALT + up", hl.dsp.exec_raw("resizeactive 0 -40"), { repeating = true })
rebind(mainMod .. " + SHIFT + equal", hl.dsp.exec_raw("resizeactive 0 40"), { repeating = true })
rebind(mainMod .. " + ALT + down", hl.dsp.exec_raw("resizeactive 0 40"), { repeating = true })

-- Submaps for Resize Mode and Move Mode
hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.exec_raw("resizeactive 25 0"), { repeating = true })
    hl.bind("left",  hl.dsp.exec_raw("resizeactive -25 0"), { repeating = true })
    hl.bind("up",    hl.dsp.exec_raw("resizeactive 0 -25"), { repeating = true })
    hl.bind("down",  hl.dsp.exec_raw("resizeactive 0 25"), { repeating = true })
    hl.bind("Escape", hl.dsp.exec_raw("submap reset"))
    hl.bind("Return", hl.dsp.exec_raw("submap reset"))
end)

hl.define_submap("move", function()
    hl.bind("right", hl.dsp.exec_raw("moveactive 25 0"), { repeating = true })
    hl.bind("left",  hl.dsp.exec_raw("moveactive -25 0"), { repeating = true })
    hl.bind("up",    hl.dsp.exec_raw("moveactive 0 -25"), { repeating = true })
    hl.bind("down",  hl.dsp.exec_raw("moveactive 0 25"), { repeating = true })
    hl.bind("Escape", hl.dsp.exec_raw("submap reset"))
    hl.bind("Return", hl.dsp.exec_raw("submap reset"))
end)

-- Directional focus
rebind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
rebind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
rebind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
rebind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Mouse drag window moving/resizing
rebind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
rebind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ------------------------------------------------------------------------------
-- 5. WINDOW GROUPS / TABBING
-- ------------------------------------------------------------------------------
rebind("ALT + Tab", hl.dsp.exec_raw("cyclenext"))
rebind("SHIFT + ALT + Tab", hl.dsp.exec_raw("cyclenext prev"))
rebind("CTRL + ALT + Tab", hl.dsp.exec_raw("changegroupactive f"))
rebind("CTRL + SHIFT + ALT + Tab", hl.dsp.exec_raw("changegroupactive b"))
rebind(mainMod .. " + comma", hl.dsp.exec_raw("togglegroup"))
rebind(mainMod .. " + U", hl.dsp.exec_raw("moveoutofgroup"))
rebind(mainMod .. " + SHIFT + comma", hl.dsp.exec_raw("lockactivegroup toggle"))

-- ------------------------------------------------------------------------------
-- 6. APPLICATIONS
-- ------------------------------------------------------------------------------
rebind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
rebind(mainMod .. " + W", hl.dsp.exec_cmd("firefox"))
rebind(mainMod .. " + C", hl.dsp.exec_cmd("codium"))
rebind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
rebind("CTRL + ALT + V", hl.dsp.exec_cmd("pwvucontrol"))

-- ------------------------------------------------------------------------------
-- 7. UTILITIES & CAPTURE
-- ------------------------------------------------------------------------------
rebind("Print", hl.dsp.exec_cmd(qsScript .. "screenshot.sh --fullscreen"))
rebind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(qsScript .. "screenshot.sh --region"))

-- ------------------------------------------------------------------------------
-- 8. MEDIA & AUDIO
-- ------------------------------------------------------------------------------
rebind("CTRL + " .. mainMod .. " + SPACE", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh play-pause"))
rebind("CTRL + " .. mainMod .. " + equal", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh next"))
rebind("CTRL + " .. mainMod .. " + minus", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh previous"))
rebind("CTRL + " .. mainMod .. " + BackSpace", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh stop"))
rebind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Hardware multimedia keys
rebind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
rebind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
rebind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
rebind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
rebind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
rebind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
rebind("XF86AudioNext",  hl.dsp.exec_cmd(qsScript .. "media_ctl.sh next"),       { locked = true })
rebind("XF86AudioPause", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh play-pause"), { locked = true })
rebind("XF86AudioPlay",  hl.dsp.exec_cmd(qsScript .. "media_ctl.sh play-pause"), { locked = true })
rebind("XF86AudioPrev",  hl.dsp.exec_cmd(qsScript .. "media_ctl.sh previous"),   { locked = true })

-- ------------------------------------------------------------------------------
-- 9. CLIPBOARD & EMOJIS
-- ------------------------------------------------------------------------------
rebind(mainMod .. " + V", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleClipboard"))
rebind(mainMod .. " + ALT + V", hl.dsp.exec_cmd(qsScript .. "clipboard.sh delete-latest"))
rebind("CTRL + SHIFT + ALT + V", hl.dsp.exec_cmd(qsScript .. "clipboard.sh paste-latest"))
rebind(mainMod .. " + period", hl.dsp.exec_cmd("command -v rofi >/dev/null 2>&1 && rofi -show emoji || (command -v wofi >/dev/null 2>&1 && wofi --show dmenu)"))

-- ------------------------------------------------------------------------------
-- 10. SYSTEM & INTERFACE
-- ------------------------------------------------------------------------------
rebind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleLauncher"), { release = true })
rebind(mainMod .. " + SUPER_R", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleLauncher"), { release = true })
rebind(mainMod .. " + SPACE",   hl.dsp.exec_cmd("quickshell ipc -n call shell nextKeyboardLayout"), { locked = true })
rebind("CTRL + ALT + Delete", hl.dsp.exec_cmd("quickshell ipc -n call shell togglePowerOsd"))
rebind(mainMod .. " + N", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleControlCenter"))
rebind("CTRL + ALT + C", hl.dsp.exec_cmd("quickshell ipc -n call shell clearNotifs"))
rebind(mainMod .. " + L", hl.dsp.exec_cmd("quickshell ipc -n call shell lock"))
rebind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("quickshell ipc -n call shell lock"))
rebind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd(qsScript .. "power-action.sh suspend"))
rebind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(qsScript .. "restart-shell.sh"))
rebind(mainMod .. " + slash",    hl.dsp.exec_cmd("quickshell ipc -n call shell toggleCheatSheet"))
rebind(mainMod .. " + question", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleCheatSheet"))
