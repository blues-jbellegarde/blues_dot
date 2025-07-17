-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
--local config = wezterm.config_builder()
local config = {}

-- This is where you actually apply your config choices
-- For example, changing the color scheme:
config.color_scheme_dirs = { "~/.config/wezterm/colors" }
config.color_scheme = "Solarized Osaka Night"
config.font = wezterm.font("FiraCode Nerd Font")
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{ key = "a", mods = "LEADER|CTRL", action = wezterm.action({ SendString = "\x01" }) },
	{ key = "v", mods = "LEADER", action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }) },
	{ key = "s", mods = "LEADER", action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }) },
	{ key = "z", mods = "LEADER", action = "TogglePaneZoomState" },
	{ key = "h", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
	{ key = "j", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
	{ key = "k", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
	{ key = "l", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
	{ key = "H", mods = "LEADER|SHIFT", action = wezterm.action({ AdjustPaneSize = { "Left", 5 } }) },
	{ key = "J", mods = "LEADER|SHIFT", action = wezterm.action({ AdjustPaneSize = { "Down", 5 } }) },
	{ key = "K", mods = "LEADER|SHIFT", action = wezterm.action({ AdjustPaneSize = { "Up", 5 } }) },
	{ key = "L", mods = "LEADER|SHIFT", action = wezterm.action({ AdjustPaneSize = { "Right", 5 } }) },
	{ key = "H", mods = "LEADER|CTRL", action = wezterm.action({ AdjustPaneSize = { "Left", 1 } }) },
	{ key = "J", mods = "LEADER|CTRL", action = wezterm.action({ AdjustPaneSize = { "Down", 1 } }) },
	{ key = "K", mods = "LEADER|CTRL", action = wezterm.action({ AdjustPaneSize = { "Up", 1 } }) },
	{ key = "L", mods = "LEADER|CTRL", action = wezterm.action({ AdjustPaneSize = { "Right", 1 } }) },
	{ key = "q", mods = "LEADER", action = wezterm.action({ CloseCurrentTab = { confirm = true } }) },
	{
		key = "Enter",
		mods = "LEADER",
		action = wezterm.action.ActivateCopyMode,
	},
}
for i = 1, 9 do
	table.insert(config.keys, {
		key = tostring(i),
		mods = "LEADER",
		action = wezterm.action.ActivateTab(i - 1),
	})
end
-- config.background = {
-- {
-- 	source = {
-- 		File = "/Users/jbellegarde/Documents/BluesLogomark-Black-Large.png",
-- 	},
-- 	attachment = "Fixed",
-- 	height = "Contain",
-- 	width = "Contain",
-- 	vertical_align = "Middle",
-- 	repeat_x = "NoRepeat",
-- 	repeat_y = "NoRepeat",
-- 	opacity = 0.0,
-- },
-- }

-- and finally, return the configuration to wezterm
return config
