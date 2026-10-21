-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Initial geometry and appearance
config.initial_cols = 120
config.initial_rows = 28
config.color_scheme = "AdventureTime"
config.font = wezterm.font("Zx Proto")
config.font_size = 15

-- Hide native WezTerm tab bar since Herdr manages workspaces, tabs, and panes
config.enable_tab_bar = false

-- Make Left Option act as standard Alt/Meta for terminal/Neovim shortcuts
config.send_composed_key_when_left_alt_is_pressed = false

-- Forward macOS Cmd shortcuts into Herdr (mapped to Ctrl+Alt chords in ~/.config/herdr/config.toml)
-- This leaves Ctrl+h/j/k/l completely free for Neovim splits.
config.keys = {
  -- Pane navigation (Cmd + h/j/k/l, Cmd + ; for last pane)
  { key = "h", mods = "CMD", action = act.SendKey({ key = "h", mods = "CTRL|ALT" }) },
  { key = "j", mods = "CMD", action = act.SendKey({ key = "j", mods = "CTRL|ALT" }) },
  { key = "k", mods = "CMD", action = act.SendKey({ key = "k", mods = "CTRL|ALT" }) },
  { key = "l", mods = "CMD", action = act.SendKey({ key = "l", mods = "CTRL|ALT" }) },
  { key = ";", mods = "CMD", action = act.SendKey({ key = "a", mods = "CTRL|ALT" }) },

  -- Splits, Zoom & Close Pane
  { key = "d", mods = "CMD", action = act.SendKey({ key = "d", mods = "CTRL|ALT" }) },         -- Split right (vertical)
  { key = "d", mods = "CMD|SHIFT", action = act.SendKey({ key = "s", mods = "CTRL|ALT" }) },   -- Split down (horizontal)
  { key = "D", mods = "CMD|SHIFT", action = act.SendKey({ key = "s", mods = "CTRL|ALT" }) },   -- Split down (horizontal)
  { key = "z", mods = "CMD", action = act.SendKey({ key = "z", mods = "CTRL|ALT" }) },         -- Toggle pane zoom
  { key = "Enter", mods = "CMD", action = act.SendKey({ key = "z", mods = "CTRL|ALT" }) },     -- Toggle pane zoom (alias)
  { key = "w", mods = "CMD", action = act.SendKey({ key = "w", mods = "CTRL|ALT" }) },         -- Close focused Herdr pane

  -- Direct Pane Resizing (Cmd + Arrow Keys)
  { key = "LeftArrow", mods = "CMD", action = act.SendKey({ key = "LeftArrow", mods = "CTRL|ALT" }) },
  { key = "DownArrow", mods = "CMD", action = act.SendKey({ key = "DownArrow", mods = "CTRL|ALT" }) },
  { key = "UpArrow", mods = "CMD", action = act.SendKey({ key = "UpArrow", mods = "CTRL|ALT" }) },
  { key = "RightArrow", mods = "CMD", action = act.SendKey({ key = "RightArrow", mods = "CTRL|ALT" }) },

  -- Herdr Tabs (Cmd+t new, Cmd+[/] prev/next)
  { key = "t", mods = "CMD", action = act.SendKey({ key = "t", mods = "CTRL|ALT" }) },
  { key = "[", mods = "CMD", action = act.SendKey({ key = "p", mods = "CTRL|ALT" }) },
  { key = "]", mods = "CMD", action = act.SendKey({ key = "n", mods = "CTRL|ALT" }) },

  -- Herdr Workspaces (Cmd+Shift+[/] prev/next workspace)
  { key = "[", mods = "CMD|SHIFT", action = act.SendKey({ key = "e", mods = "CTRL|ALT" }) },
  { key = "]", mods = "CMD|SHIFT", action = act.SendKey({ key = "f", mods = "CTRL|ALT" }) },
  { key = "{", mods = "CMD", action = act.SendKey({ key = "e", mods = "CTRL|ALT" }) },
  { key = "}", mods = "CMD", action = act.SendKey({ key = "f", mods = "CTRL|ALT" }) },
  { key = "{", mods = "CMD|SHIFT", action = act.SendKey({ key = "e", mods = "CTRL|ALT" }) },
  { key = "}", mods = "CMD|SHIFT", action = act.SendKey({ key = "f", mods = "CTRL|ALT" }) },

  -- Herdr Sidebar, Goto Picker, Notifications & Popups
  { key = "b", mods = "CMD", action = act.SendKey({ key = "b", mods = "CTRL|ALT" }) },         -- Toggle Herdr sidebar
  { key = "g", mods = "CMD", action = act.SendKey({ key = "g", mods = "CTRL|ALT" }) },         -- Goto agent/pane picker
  { key = "p", mods = "CMD", action = act.SendKey({ key = "g", mods = "CTRL|ALT" }) },         -- Goto picker (Cmd+p alias)
  { key = "o", mods = "CMD", action = act.SendKey({ key = "o", mods = "CTRL|ALT" }) },         -- Jump to notification target
  { key = "u", mods = "CMD", action = act.SendKey({ key = "u", mods = "CTRL|ALT" }) },         -- Lazygit floating popup
  { key = "y", mods = "CMD", action = act.SendKey({ key = "y", mods = "CTRL|ALT" }) },         -- Scratch terminal popup

  -- Disable built-in WezTerm split/tab bindings so Herdr owns all splits and tabs
  { key = '"', mods = "CTRL|ALT", action = act.DisableDefaultAssignment },
  { key = '"', mods = "SHIFT|CTRL|ALT", action = act.DisableDefaultAssignment },
  { key = "'", mods = "SHIFT|CTRL|ALT", action = act.DisableDefaultAssignment },
  { key = "%", mods = "CTRL|ALT", action = act.DisableDefaultAssignment },
  { key = "%", mods = "SHIFT|CTRL|ALT", action = act.DisableDefaultAssignment },
  { key = "5", mods = "SHIFT|CTRL|ALT", action = act.DisableDefaultAssignment },
  { key = "t", mods = "SHIFT|CTRL", action = act.DisableDefaultAssignment },
  { key = "T", mods = "SHIFT|CTRL", action = act.DisableDefaultAssignment },
  { key = "T", mods = "CTRL", action = act.DisableDefaultAssignment },
}

-- Cmd + 1..9 switches Herdr tabs directly (sent as Alt+1..9 since digits don't have ASCII Ctrl codes)
for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "CMD",
    action = act.SendKey({ key = tostring(i), mods = "ALT" }),
  })
end

return config
