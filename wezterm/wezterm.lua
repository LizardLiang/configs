--- wezterm.lua
--- $ figlet -f small Wezterm
--- __      __      _
--- \ \    / /__ __| |_ ___ _ _ _ __
---  \ \/\/ / -_)_ /  _/ -_) '_| '  \
---   \_/\_/\___/__|\__\___|_| |_|_|_|
---
--- My Wezterm config file

local wezterm = require("wezterm")
local act = wezterm.action

local pwsh_path = "C:\\Program Files\\PowerShell\\7\\pwsh.exe"

local config = {}
-- Use config builder object if possible
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Settings
config.default_prog = { pwsh_path }

config.color_scheme = "Tokyo Night"
config.colors = {
	tab_bar = {
		background = "#1a1b26",
		active_tab = {
			bg_color = "#292e42",
			fg_color = "#7aa2f7",
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = "#1a1b26",
			fg_color = "#565f89",
		},
		inactive_tab_hover = {
			bg_color = "#292e42",
			fg_color = "#c0caf5",
		},
		new_tab = {
			bg_color = "#1a1b26",
			fg_color = "#565f89",
		},
		new_tab_hover = {
			bg_color = "#292e42",
			fg_color = "#7aa2f7",
		},
	},
}
config.font = wezterm.font_with_fallback({
	{ family = "Sarasa Term TC" },
	{ family = "FiraCode Nerd Font Mono" },
	{ family = "FiraCode Nerd Font" },
})
config.font_size = 14
config.window_background_opacity = 0
config.win32_system_backdrop = "Acrylic"
config.text_background_opacity = 0.8
config.background = {
	{
		source = { Color = "#1a1b26" },
		width = "100%",
		height = "100%",
		opacity = 0.97,
	},
	{
		source = { File = "C:\\Users\\lizard_liang\\Pictures\\343502-universe-black_holes.jpg" },
		hsb = { brightness = 0.15, hue = 1.0, saturation = 1.0 },
		opacity = 0.2,
	},
}
config.window_decorations = "RESIZE"
config.window_close_confirmation = "AlwaysPrompt"
config.scrollback_lines = 3000
config.default_workspace = "main"

-- Dim inactive panes
config.inactive_pane_hsb = {
	saturation = 0.24,
	brightness = 0.5,
}

function SwitchPaneWithZoomState(window, pane, line, direction)
	local panes = window:active_tab():panes_with_info()
	local is_zoomed = false
	for _, item in ipairs(panes) do
		if item.is_active then
			is_zoomed = item.is_zoomed
		end
	end

	local next_pane = window:active_tab():get_pane_direction(direction)
	if next_pane == nil then
		if direction == "Left" then
			next_pane = panes[#panes].pane
		elseif direction == "Right" then
			next_pane = panes[1].pane
		end
	end

	window:active_tab():set_zoomed(false)
	next_pane:activate()
	window:active_tab():set_zoomed(is_zoomed)
end

-- Keys
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1500 }
config.keys = {
	-- Passthrough
	{ key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },
	{ key = "Enter", mods = "SHIFT", action = act.SendString("\n") },
	-- Send C-a when pressing C-a twice (tmux passthrough)
	{ key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },
	{ key = "phys:Space", mods = "LEADER", action = act.ActivateCommandPalette },

	-- Windows (tabs) — tmux style
	{ key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") }, -- new window
	{ key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) }, -- next window
	{ key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) }, -- prev window
	{ key = "w", mods = "LEADER", action = act.ShowTabNavigator }, -- list windows
	{ key = "&", mods = "LEADER|SHIFT", action = act.CloseCurrentTab({ confirm = true }) }, -- kill window
	{
		key = "e",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = wezterm.format({
				{ Attribute = { Intensity = "Bold" } },
				{ Foreground = { AnsiColor = "Fuchsia" } },
				{ Text = "Rename window:" },
			}),
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
	-- Move windows
	{ key = "m", mods = "LEADER", action = act.ActivateKeyTable({ name = "move_tab", one_shot = false }) },
	{ key = "{", mods = "LEADER|SHIFT", action = act.MoveTabRelative(-1) },
	{ key = "}", mods = "LEADER|SHIFT", action = act.MoveTabRelative(1) },

	-- Panes — tmux style
	{
		key = '"',
		mods = "LEADER|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local cwd = pane:get_current_working_dir()
			local cwd_path = cwd and cwd.file_path:gsub("^/", "") or nil
			window:perform_action(act.SplitVertical({ domain = "CurrentPaneDomain", cwd = cwd_path }), pane)
		end),
	}, -- split below (LEADER + ")
	{
		key = "%",
		mods = "LEADER|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local cwd = pane:get_current_working_dir()
			local cwd_path = cwd and cwd.file_path:gsub("^/", "") or nil
			window:perform_action(act.SplitHorizontal({ domain = "CurrentPaneDomain", cwd = cwd_path }), pane)
		end),
	}, -- split right (LEADER + %)
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) }, -- kill pane
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState }, -- zoom pane
	{ key = "o", mods = "LEADER", action = act.RotatePanes("Clockwise") },
	-- Navigate panes (vim-style)
	{
		key = "h",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Left")
		end),
	},
	{
		key = "j",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Down")
		end),
	},
	{
		key = "k",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Up")
		end),
	},
	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Right")
		end),
	},
	-- Also support arrow keys for pane switching
	{
		key = "LeftArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Left")
		end),
	},
	{
		key = "RightArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Right")
		end),
	},
	-- Navigate panes with CTRL+Arrow
	{
		key = "LeftArrow",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Left")
		end),
	},
	{
		key = "RightArrow",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Right")
		end),
	},
	{
		key = "UpArrow",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Up")
		end),
	},
	{
		key = "DownArrow",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane, line)
			SwitchPaneWithZoomState(window, pane, line, "Down")
		end),
	},
	-- Resize panes
	{
		key = "r",
		mods = "LEADER",
		action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }),
	},

	-- Copy mode (tmux [)
	{ key = "[", mods = "LEADER", action = act.ActivateCopyMode },

	-- Workspace
	{ key = "s", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
}
-- I can use the tab navigator (LDR t), but I also want to quickly navigate tabs with index
for i = 1, 9 do
	table.insert(config.keys, {
		key = tostring(i),
		mods = "LEADER",
		action = act.ActivateTab(i - 1),
	})
end

config.key_tables = {
	resize_pane = {
		{ key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
		{ key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
		{ key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
		{ key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Enter", action = "PopKeyTable" },
	},
	move_tab = {
		{ key = "h", action = act.MoveTabRelative(-1) },
		{ key = "j", action = act.MoveTabRelative(-1) },
		{ key = "k", action = act.MoveTabRelative(1) },
		{ key = "l", action = act.MoveTabRelative(1) },
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Enter", action = "PopKeyTable" },
	},
}

-- Tab bar
-- I don't like the look of "fancy" tab bar
config.use_fancy_tab_bar = false
config.status_update_interval = 1000
config.tab_bar_at_bottom = false

wezterm.on("update-status", function(window, pane)
	-- Workspace name
	local stat = window:active_workspace()
	local stat_color = "#f7768e"
	-- It's a little silly to have workspace name all the time
	-- Utilize this to display LDR or current key table name
	if window:active_key_table() then
		stat = window:active_key_table()
		stat_color = "#7dcfff"
	end
	if window:leader_is_active() then
		stat = "LDR"
		stat_color = "#bb9af7"
	end

	-- Current working directory
	local basename = function(s)
		-- Nothing a little regex can't fix

		return string.gsub(s, "(.*[/\\])(.*)", "%2")
	end
	-- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l). Not a big deal, but check in case
	local cwd = pane:get_current_working_dir()
	cwd = cwd and basename(cwd.path) or ""
	-- Current command
	local cmd = pane:get_foreground_process_name()
	cmd = cmd and basename(cmd) or ""

	-- Time
	local time = wezterm.strftime("%H:%M")

	-- Left status (left of the tab line)
	window:set_left_status(wezterm.format({
		{ Foreground = { Color = stat_color } },
		{ Text = "  " },
		{ Text = wezterm.nerdfonts.oct_table .. "  " .. stat },
		{ Text = " |" },
	}))

	-- Right status
	window:set_right_status(wezterm.format({
		-- Wezterm has a built-in nerd fonts
		-- https://wezfurlong.org/wezterm/config/lua/wezterm/nerdfonts.html
		{ Text = wezterm.nerdfonts.md_folder .. "  " .. cwd },
		{ Text = " | " },
		{ Foreground = { Color = "#e0af68" } },
		{ Text = wezterm.nerdfonts.fa_code .. "  " .. cmd },
		"ResetAttributes",
		{ Text = " | " },
		{ Text = wezterm.nerdfonts.md_clock .. "  " .. time },
		{ Text = "  " },
	}))
end)

return config
