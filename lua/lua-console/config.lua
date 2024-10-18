local config = {
  buffer = {
    prepend_result_with = '\n=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    lsp = true
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
