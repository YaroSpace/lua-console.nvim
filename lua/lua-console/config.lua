local config = {
  buffer = {
    lsp = true,
    prepend_result_with = '\n=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    load_on_start = true
  },
  window = {
    relative = 'editor',
    anchor = 'SW',
    style = 'minimal',
    border = { '╔', '═' ,'╗', '║', '╝', '═', '╚', '║' },
    title = ' Lua console ',
    title_pos = 'left',
    zindex = 1,
  },
  mappings = {
    toggle = '`',
    eval = '<CR>',  -- <C-J> is to catch <C-Enter>
    clear = 'C',
    messages = 'M',
    save = 'S',
    load = 'L'
  }
}

return config
