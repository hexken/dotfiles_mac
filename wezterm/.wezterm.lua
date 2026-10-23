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

-- Forward macOS Cmd shortcuts into Herdr via Herdr's prefix (Ctrl+a = \x01)
-- This sends the prefix + command character directly into the terminal,
-- which bypasses OS/terminal control byte collisions (like Ctrl+h = Backspace, Ctrl+j = Enter)
-- and leaves Ctrl+h/j/k/l completely free for Neovim splits.
config.keys = {
  -- Pane navigation (Cmd + h/j/k/l, Cmd + ; for last pane)
  { key = "h", mods = "CMD", action = act.SendString("\x01h") },
  { key = "j", mods = "CMD", action = act.SendString("\x01j") },
  { key = "k", mods = "CMD", action = act.SendString("\x01k") },
  { key = "l", mods = "CMD", action = act.SendString("\x01l") },
  { key = ";", mods = "CMD", action = act.SendString("\x01;") },

  -- Splits, Zoom & Close Pane
  { key = "d", mods = "CMD", action = act.SendString("\x01v") },         -- Split right (vertical)
  { key = "d", mods = "CMD|SHIFT", action = act.SendString("\x01-") },   -- Split down (horizontal)
  { key = "D", mods = "CMD|SHIFT", action = act.SendString("\x01-") },   -- Split down (horizontal)
  { key = "z", mods = "CMD", action = act.SendString("\x01z") },         -- Toggle pane zoom
  { key = "Enter", mods = "CMD", action = act.SendString("\x01z") },     -- Toggle pane zoom (alias)
  { key = "w", mods = "CMD", action = act.SendString("\x01x") },         -- Close focused Herdr pane

  -- Direct Pane Resizing (Cmd + Arrow Keys)
  { key = "LeftArrow", mods = "CMD", action = act.SendString("\x01\x1b[D") },
  { key = "DownArrow", mods = "CMD", action = act.SendString("\x01\x1b[B") },
  { key = "UpArrow", mods = "CMD", action = act.SendString("\x01\x1b[A") },
  { key = "RightArrow", mods = "CMD", action = act.SendString("\x01\x1b[C") },

  -- Herdr Tabs (Cmd+t new, Cmd+[/] prev/next)
  { key = "t", mods = "CMD", action = act.SendString("\x01c") },
  { key = "[", mods = "CMD", action = act.SendString("\x01p") },
  { key = "]", mods = "CMD", action = act.SendString("\x01n") },

  -- Herdr Workspaces (Cmd+Shift+[/] prev/next workspace)
  { key = "[", mods = "CMD|SHIFT", action = act.SendString("\x01{") },
  { key = "]", mods = "CMD|SHIFT", action = act.SendString("\x01}") },
  { key = "{", mods = "CMD", action = act.SendString("\x01{") },
  { key = "}", mods = "CMD", action = act.SendString("\x01}") },
  { key = "{", mods = "CMD|SHIFT", action = act.SendString("\x01{") },
  { key = "}", mods = "CMD|SHIFT", action = act.SendString("\x01}") },

  -- Herdr Sidebar, Goto Picker, Notifications & Popups
  { key = "b", mods = "CMD", action = act.SendString("\x01b") },         -- Toggle Herdr sidebar
  { key = "g", mods = "CMD", action = act.SendString("\x01g") },         -- Goto agent/pane picker
  { key = "p", mods = "CMD", action = act.SendString("\x01g") },         -- Goto picker (Cmd+p alias)
  { key = "o", mods = "CMD", action = act.SendString("\x01o") },         -- Jump to notification target
  { key = "u", mods = "CMD", action = act.SendString("\x01u") },         -- Lazygit floating popup
  { key = "y", mods = "CMD", action = act.SendString("\x01t") },         -- Scratch terminal popup

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

-- Cmd + 1..9 switches Herdr tabs directly (Ctrl+a then 1..9)
for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "CMD",
    action = act.SendString("\x01" .. tostring(i)),
  })
end

return config
