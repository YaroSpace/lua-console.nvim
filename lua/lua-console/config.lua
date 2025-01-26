local M = {}

local default_config = {
  buffer = {
    result_prefix = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    autosave = true, -- autosave on console hide / close
    load_on_start = true, -- load saved session on start
    preserve_context = true, -- preserve results between evaluations
  },
  window = {
    relative = 'editor',
    anchor = 'SW',
    style = 'minimal',
    border = 'double', -- single|double|rounded
    title = ' Lua console ',
    title_pos = 'left',
    height = 0.6, -- percentage of main window
    zindex = 100,
  },
  mappings = {
    toggle = '`',
    attach = '<Leader>`',
    quit = 'q',
    eval = '<CR>',
    eval_buffer = '<S-CR>',
    open = 'gf',
    messages = 'M',
    save = 'S',
    load = 'L',
    resize_up = '<C-Up>',
    resize_down = '<C-Down>',
    help = '?',
  },
}

M.setup = function(opts)
  default_config.external_evaluators = require('lua-console.exev_config')
  default_config = vim.tbl_deep_extend('force', default_config, opts or {})

  setmetatable(M, { __index = default_config })
  return M
end

return M
