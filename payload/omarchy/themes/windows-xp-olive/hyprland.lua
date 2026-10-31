-- Windows XP (Olive Green) -- Hyprland colours only.
--
-- This file loads BEFORE hypr/looknfeel.lua (see omarchy/xp task0-recon Q2),
-- so gaps, border size and rounding set here would be overridden. Those live
-- in omarchy/xp/hypr/late.lua instead. No screen-shader settings: the CRT
-- shader stays independently toggleable with hypr/bin/crt-shader.
local active_border_color = "rgb(8ba169)"
local inactive_border_color = "rgb(d4d6ba)"

hl.config({
	general = {
		col = {
			active_border = active_border_color,
			inactive_border = inactive_border_color,
		},
	},

	group = {
		col = {
			border_active = active_border_color,
			border_inactive = inactive_border_color,
		},

		-- Taskbar buttons: the focused tab is the pressed (darker) button.
		groupbar = {
			text_color = "rgb(ffffff)",
			text_color_inactive = "rgb(ffffff)",
			col = {
				active = "rgb(2b5b22)",
				inactive = "rgb(5e764f)",
			},
		},
	},
})
