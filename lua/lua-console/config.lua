local config = {
  buffer = {
    prepend_result_with = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    load_on_start = true -- load saved session on first entry
  },
  window = {
    relative = 'editor',
    anchor = 'SW',
    style = 'minimal',
    border = { '╔', '═' ,'╗', '║', '╝', '═', '╚', '║' },
    title = ' Lua console ',
    title_pos = 'left',
    -- @field height number Percentage of main window
    height = 0.6,
    zindex = 1,
  },
  mappings = {
    toggle = '`',
    eval = '<CR>',  -- or <C-J> for <C-Enter>
    clear = 'C',
    messages = 'M',
    save = 'S',
    load = 'L'
  }
}

return config
