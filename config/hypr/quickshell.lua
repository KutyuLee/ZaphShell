-- ==============================================================================
-- CHROMASHELL HYPRLAND LUA CONFIGURATION MODULE
-- Include this file in your main hyprland.lua:
--   dofile(os.getenv("HOME") .. "/.config/hypr/quickshell.lua")
-- ==============================================================================

local mainMod = "SUPER"
local home = os.getenv("HOME") or ""
local qsScript = home .. "/.config/quickshell/scripts/"

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
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    -- Switch workspace group (group 0/1 = 1-10, group 2 = 11-20, etc.)
    hl.bind("CTRL + " .. mainMod .. " + " .. key, hl.dsp.focus({ workspace = (i == 10 and 10 or i) * 10 - 9 }))
    -- Move window to workspace
    hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i }))
    -- Move window to workspace silently
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, silent = true }))
    -- Move window to workspace group
    hl.bind("CTRL + " .. mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = (i == 10 and 10 or i) * 10 - 9 }))
end

-- Next Workspace
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("CTRL + " .. mainMod .. " + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + Next", hl.dsp.focus({ workspace = "e+1" }))

-- Previous Workspace
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL + " .. mainMod .. " + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + Prior", hl.dsp.focus({ workspace = "e-1" }))

-- Next Workspace Group
hl.bind("CTRL + " .. mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "+10" }))
-- Previous Workspace Group
hl.bind("CTRL + " .. mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "-10" }))

-- Move Window to Next / Prev Workspace
hl.bind(mainMod .. " + ALT + mouse_down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + ALT + Next", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }))

hl.bind(mainMod .. " + ALT + mouse_up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. " + ALT + Prior", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + left", hl.dsp.window.move({ workspace = "e-1" }))

-- Move Window to / from Special Workspace
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + up", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + down", hl.dsp.window.move({ workspace = "e" }))

-- Show / Hide Desktop (Win+D style single-hand toggle)
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(qsScript .. "show-desktop.sh"))

-- ------------------------------------------------------------------------------
-- 3. SPECIAL WORKSPACES (SCRATCHPADS)
-- ------------------------------------------------------------------------------
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh magic"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh sysmon"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh music"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(qsScript .. "scratchpad.sh comm"))

-- ------------------------------------------------------------------------------
-- 4. WINDOW ACTIONS & SIZING
-- ------------------------------------------------------------------------------
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + ALT + F", hl.dsp.exec_raw("fullscreen 1"))
hl.bind(mainMod .. " + ALT + backslash", hl.dsp.exec_raw("setfloating; pin; resizeactive exact 480 270"))
hl.bind(mainMod .. " + P", hl.dsp.window.pin())
hl.bind(mainMod .. " + Z", hl.dsp.exec_raw("submap move"))
hl.bind(mainMod .. " + X", hl.dsp.exec_raw("submap resize"))
hl.bind("CTRL + " .. mainMod .. " + backslash", hl.dsp.exec_raw("centerwindow"))
hl.bind("CTRL + " .. mainMod .. " + ALT + backslash", hl.dsp.exec_raw("resizeactive exact 50% 50%; centerwindow"))

-- Incremental width/height adjustments
hl.bind(mainMod .. " + minus", hl.dsp.exec_raw("resizeactive -40 0"), { repeating = true })
hl.bind(mainMod .. " + ALT + left", hl.dsp.exec_raw("resizeactive -40 0"), { repeating = true })
hl.bind(mainMod .. " + equal", hl.dsp.exec_raw("resizeactive 40 0"), { repeating = true })
hl.bind(mainMod .. " + ALT + right", hl.dsp.exec_raw("resizeactive 40 0"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.exec_raw("resizeactive 0 -40"), { repeating = true })
hl.bind(mainMod .. " + ALT + up", hl.dsp.exec_raw("resizeactive 0 -40"), { repeating = true })
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.exec_raw("resizeactive 0 40"), { repeating = true })
hl.bind(mainMod .. " + ALT + down", hl.dsp.exec_raw("resizeactive 0 40"), { repeating = true })

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
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Mouse drag window moving/resizing
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ------------------------------------------------------------------------------
-- 5. WINDOW GROUPS / TABBING
-- ------------------------------------------------------------------------------
hl.bind("ALT + Tab", hl.dsp.exec_raw("cyclenext"))
hl.bind("SHIFT + ALT + Tab", hl.dsp.exec_raw("cyclenext prev"))
hl.bind("CTRL + ALT + Tab", hl.dsp.exec_raw("changegroupactive f"))
hl.bind("CTRL + SHIFT + ALT + Tab", hl.dsp.exec_raw("changegroupactive b"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_raw("togglegroup"))
hl.bind(mainMod .. " + U", hl.dsp.exec_raw("moveoutofgroup"))
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.exec_raw("lockactivegroup toggle"))

-- ------------------------------------------------------------------------------
-- 6. APPLICATIONS
-- ------------------------------------------------------------------------------
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("codium"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd("pwvucontrol"))

-- ------------------------------------------------------------------------------
-- 7. UTILITIES & CAPTURE
-- ------------------------------------------------------------------------------
hl.bind("Print", hl.dsp.exec_cmd(qsScript .. "screenshot.sh --fullscreen"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(qsScript .. "screenshot.sh --region"))

-- ------------------------------------------------------------------------------
-- 8. MEDIA & AUDIO
-- ------------------------------------------------------------------------------
hl.bind("CTRL + " .. mainMod .. " + SPACE", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh play-pause"))
hl.bind("CTRL + " .. mainMod .. " + equal", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh next"))
hl.bind("CTRL + " .. mainMod .. " + minus", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh previous"))
hl.bind("CTRL + " .. mainMod .. " + BackSpace", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh stop"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Hardware multimedia keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(qsScript .. "media_ctl.sh next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(qsScript .. "media_ctl.sh play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(qsScript .. "media_ctl.sh play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(qsScript .. "media_ctl.sh previous"),   { locked = true })

-- ------------------------------------------------------------------------------
-- 9. CLIPBOARD & EMOJIS
-- ------------------------------------------------------------------------------
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleClipboard"))
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd(qsScript .. "clipboard.sh delete-latest"))
hl.bind("CTRL + SHIFT + ALT + V", hl.dsp.exec_cmd(qsScript .. "clipboard.sh paste-latest"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("command -v rofi >/dev/null 2>&1 && rofi -show emoji || (command -v wofi >/dev/null 2>&1 && wofi --show dmenu)"))

-- ------------------------------------------------------------------------------
-- 10. SYSTEM & INTERFACE
-- ------------------------------------------------------------------------------
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleLauncher"), { release = true })
hl.bind(mainMod .. " + SUPER_R", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleLauncher"), { release = true })
hl.bind(mainMod .. " + SPACE",   hl.dsp.exec_cmd("quickshell ipc -n call shell nextKeyboardLayout"), { locked = true })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("quickshell ipc -n call shell togglePowerOsd"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleControlCenter"))
hl.bind("CTRL + ALT + C", hl.dsp.exec_cmd("quickshell ipc -n call shell clearNotifs"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("quickshell ipc -n call shell lock"))
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("quickshell ipc -n call shell lock"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind(mainMod .. " + slash",    hl.dsp.exec_cmd("quickshell ipc -n call shell toggleCheatSheet"))
hl.bind(mainMod .. " + question", hl.dsp.exec_cmd("quickshell ipc -n call shell toggleCheatSheet"))
