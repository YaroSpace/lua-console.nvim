-- Rerun tests only if their modification time changed.
cache = true

std = luajit
codes = true

self = false

-- Reference: https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {
  -- Neovim lua API + luacheck thinks variables like `vim.wo.spell = true` is
  -- invalid when it actually is valid. So we have to display rule `W122`.
  --
  '122', -- setting read-only field of vim...
  '631', -- max_line_length
  '621', -- incostistant indentation
  '611', -- line with whitespace
  '111', -- setting non-standard global variable, i.e. _
}

-- Global objects defined by the C code
read_globals = {
  'vim',
  'Lua_console',
  'describe',
  'it',
  'assert',
}

exclude_files = {
  'spec/utfTerminal.lua',
}
