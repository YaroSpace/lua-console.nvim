local config = {
  buffer = {
    name = 'Lua console',
    prepend_result_with = '\n=> ',
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
    clear = 'cc',
    messages = 'm',
    save = 'S',
    load = 'L'
  }
}

return config
