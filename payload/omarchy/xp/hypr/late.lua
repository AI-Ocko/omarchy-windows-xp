-- Windows XP -- Hyprland geometry overrides that must load AFTER hypr/looknfeel.lua.
--
-- A theme's hyprland.lua runs inside the Omarchy defaults, before ocko's
-- hypr/*.lua (task0-recon Q2), so gaps/border/rounding set there lose to
-- looknfeel.lua. `xp-mode on` (omarchy/xp/bin) copies this file to
-- ~/.local/state/omarchy/toggles/hypr/windows-xp.lua, which
-- default.hypr.toggles loads last, and `xp-mode off` removes it. It also
-- guards itself: outside an XP theme it does nothing, so a stale copy left
-- behind cannot leak XP geometry.
--
-- default/hypr/require_all.lua lists that directory with `find -type f`,
-- which skips symlinks -- so it is installed as a copy, not a symlink.

local paths = require("default.hypr.paths")

local function theme_name()
	local f = io.open(paths.state_home .. "/omarchy/current/theme.name", "r")
	if not f then
		return ""
	end
	local name = f:read("*l") or ""
	f:close()
	return name
end

local name = theme_name()
if name ~= "windows-xp" and name:sub(1, 11) ~= "windows-xp-" then
	return
end

hl.config({
	general = {
		-- XP density: windows nearly touch.
		gaps_in = 2,
		gaps_out = 4,
		-- Reads like XP's 3-4px resizable frame.
		border_size = 3,
	},
	decoration = {
		-- XP rounds only the title bar's top corners; keep the frame nearly square.
		rounding = 3,
		rounding_power = 2.0,
		-- XP never dims unfocused windows; the inactive title colour is the cue.
		dim_inactive = false,
		-- XP chrome is opaque (looknfeel.lua sets 0.95).
		active_opacity = 1.0,
	},
})

-- Omarchy's default/hypr/windows.lua gives every `default-opacity`-tagged
-- window "0.985 0.96". This rule loads after it, so it wins for XP; opt-outs
-- that drop the tag are untouched. Check: hyprctl getprop address:<a> opacity
o.window({ tag = "default-opacity" }, { opacity = "1 1" })

-- XP screensaver: xscreensaver's `pipes`, started once per monitor by
-- omarchy/xp/bin/xp-screensaver. An XWayland client: its WM_CLASS is
-- ("pipes", "TopLevelShell") and Hyprland's class is Xt's generic shell
-- class, so the title narrows it. Float + fullscreen, as Omarchy does for
-- org.omarchy.screensaver, so the tiled windows behind it never reflow.
local xp_pipes = { class = "^TopLevelShell$", title = "^Pipes: .*$" }
o.window(xp_pipes, { float = true, fullscreen = true })

-- XP title bars (hyprbars, /usr/lib/libhyprbars.so from omarchy/xp/bin/xp-install-packages).
-- Declared only here, so leaving XP stops declaring it and Hyprland unloads it
-- on that same reload. hyprbars draws flat fills and round buttons only: no
-- vertical gradient, no title icon, no rounded-square buttons.
-- Colours: omarchy/xp/palette.md (caption rows, *_CAPTIONBUTTON / *_CLOSEBUTTON px 10,10).
local schemes = {
	["windows-xp"] = { bar = "0055e5", text = "ffffff", idle = "7a96df", idle_text = "d8e4f8", btn = "3b77f5", glyph = "ffffff", close = "e55f3b" },
	["windows-xp-olive"] = { bar = "aab883", text = "ffffff", idle = "d4d7bb", idle_text = "ffffff", btn = "9aa878", glyph = "ffffff", close = "d56f4a" },
	["windows-xp-silver"] = { bar = "c4c7d4", text = "0e1010", idle = "e4e5ed", idle_text = "a2a1a1", btn = "cbcbdc", glyph = "000000", close = "e06a68" },
	["windows-xp-royale"] = { bar = "3a7cd0", text = "ffffff", idle = "5886c3", idle_text = "ffffff", btn = "4584d0", glyph = "ffffff", close = "c55036" },
	["windows-xp-zune"] = { bar = "3d3d3d", text = "ffffff", idle = "2e2e2e", idle_text = "f4f4f4", btn = "464646", glyph = "ffffff", close = "de3518" },
}
local c = schemes[name] or schemes["windows-xp"]

-- The patched build (omarchy/xp/hyprbars/build) draws the real Luna caption
-- buttons. It is ABI-locked, so it is used only while the stamp written beside
-- it matches the running Hyprland; otherwise the packaged plugin and the flat
-- buttons below. Rerun the build after every Hyprland update.
local xp_bars = os.getenv("HOME") .. "/.local/lib/hyprbars-xp"
local function read_line(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local line = f:read("*l")
	f:close()
	return line
end
local xp_art = read_line(xp_bars .. "/hyprland-version") == hl.version() and io.open(xp_bars .. "/libhyprbars.so", "r") ~= nil
local art = os.getenv("HOME") .. "/.config/omarchy/xp/assets/graphics/taskbar/" .. (schemes[name] and name or "windows-xp") .. "/"

hl.plugin.load(xp_art and xp_bars .. "/libhyprbars.so" or "/usr/lib/libhyprbars.so")

-- The plugin's keys and rule effects exist only after it loads (the second
-- parse of this reload), so everything else is guarded.
if hl.plugin.hyprbars ~= nil then
	local function dispatch(lua)
		return "hyprctl dispatch '" .. lua .. "'"
	end
	local maximize = dispatch('hl.dsp.window.fullscreen({ mode = "maximized" })')

	hl.config({
		plugin = {
			hyprbars = {
				bar_height = 25,
				bar_color = "rgb(" .. c.bar .. ")",
				["col.text"] = "rgb(" .. c.text .. ")",
				bar_text_font = "Trebuchet MS",
				bar_text_size = 12,
				bar_text_weight = "bold",
				bar_text_align = "left",
				bar_padding = 6,
				bar_button_padding = 2,
				bar_buttons_alignment = "right",
				on_double_click = maximize,
			},
		},
	})

	-- First added is rightmost. bg_image/fg_image/fg_image_alt are the patched
	-- build's Luna frames (XpWindow.qml's CaptionButton, "%d" = frame 0-7); the
	-- packaged plugin ignores those keys and draws the flat colour + icon.
	local function frames(bg, fg, alt)
		return art .. bg .. "-%d.png", art .. fg .. "-%d.png", alt and art .. alt .. "-%d.png" or nil
	end
	local close_bg, close_fg = frames("win-close", "win-closeg")
	local max_bg, max_fg, max_alt = frames("win-help", "win-maxg", "win-restg")
	local min_bg, min_fg = frames("win-help", "win-ming")
	hl.plugin.hyprbars.add_button({ bg_color = "rgb(" .. c.close .. ")", fg_color = "rgb(ffffff)", size = 21, icon = "✕", action = dispatch("hl.dsp.window.close()"), bg_image = close_bg, fg_image = close_fg })
	hl.plugin.hyprbars.add_button({ bg_color = "rgb(" .. c.btn .. ")", fg_color = "rgb(" .. c.glyph .. ")", size = 21, icon = "□", action = maximize, bg_image = max_bg, fg_image = max_fg, fg_image_alt = max_alt })
	hl.plugin.hyprbars.add_button({ bg_color = "rgb(" .. c.btn .. ")", fg_color = "rgb(" .. c.glyph .. ")", size = 21, icon = "_", action = "omarchy-shell xptask minimizeActive", bg_image = min_bg, fg_image = min_fg })

	-- XP fades the caption of every window but the active one.
	o.window({ focus = false }, { ["hyprbars:bar_color"] = "rgb(" .. c.idle .. ")", ["hyprbars:title_color"] = "rgb(" .. c.idle_text .. ")" })

	-- No caption on the HUD, the screensaver, or Omarchy's floating popups.
	o.window("^(com\\.rice\\.(btop|logs)|org\\.omarchy\\.screensaver)$", { ["hyprbars:no_bar"] = true })
	o.window(xp_pipes, { ["hyprbars:no_bar"] = true })
	o.window({ tag = "floating-window" }, { ["hyprbars:no_bar"] = true })
end
