local config = {
  buffer = {
    name = 'Lua console',
    prepend_result_with = '\n=> ',
    save_path = '/tmp'
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
  }
}

return config
