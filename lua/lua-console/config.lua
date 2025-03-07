local M = {}

local default_config = {
  buffer = {
    result_prefix = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    autosave = true, -- autosave on console hide / close
    load_on_start = true, -- load saved session on start
    preserve_context = true, -- preserve results between evaluations
    strip_local = true, -- remove local identifier from source code
    show_one_line_results = true, -- prints one line results, even if already shown as virtual text
    notify_result = false, -- notify result
    clear_before_eval = false, -- clear output below result prefix before evaluation of the whole buffer
    process_timeout = 2 * 1e5, -- number of instructions to process before timeout
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
    kill_ps = '<leader>K',
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
