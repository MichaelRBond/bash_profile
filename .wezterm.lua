-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

config.audible_bell = "Disabled"
config.front_end = "WebGpu"

config.font = wezterm.font 'Jetbrains mono'
config.font_size = 13.0
config.line_height = 1.2

config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.adjust_window_size_when_changing_font_size = false
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.color_scheme = 'thwump (terminal.sexy)'

config.use_dead_keys = false
config.disable_default_key_bindings = true

config.keys = {
  { key = '+', mods = 'CMD', action = wezterm.action.IncreaseFontSize },
  { key = '-', mods = 'CMD', action = wezterm.action.DecreaseFontSize },
  { key = '0', mods = 'CMD', action = wezterm.action.ResetFontSize },
  { key = 'w', mods = 'CMD', action = wezterm.action.CloseCurrentTab{ confirm = false } },
  { key = 'v', mods = 'CMD', action = wezterm.action.PasteFrom 'Clipboard' },
  { key = 'c', mods = 'CMD', action = wezterm.action.CopyTo 'Clipboard' },
  { key = 'n', mods = 'CMD', action = wezterm.action.SpawnWindow },
}

-- and finally, return the configuration to wezterm
return config
