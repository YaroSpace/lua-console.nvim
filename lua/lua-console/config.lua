local M = {}

local default_config = {
  buffer = {
    prepend_result_with = '=> ',
    save_path = vim.fn.stdpath('state') .. '/lua-console.lua',
    load_on_start = true, -- load saved session on first entry
    preserve_context = true
  },
  window = {
    relative = 'editor',
    anchor = 'SW',
    style = 'minimal',
    border = 'double',  -- single|double|rounded
    title = ' Lua console ',
    title_pos = 'left',
    height = 0.6, -- percentage of main window
    zindex = 1,
  },
  mappings = {
    toggle = '`',
    quit = 'q',
    eval = '<CR>',
    clear = 'C',
    messages = 'M',
    save = 'S',
    load = 'L',
    resize_up = '<C-Up>',
    resize_down = '<C-Down>',
    help = '?'
  },
  external_evaluators = {
    ruby = {
      cmd = { 'ruby', '-e' },
      env = { RUBY_VERSION = '3.3.0' },
      prepend_code = '$stdout.sync = true;',
      formatter = function(result)
        local sep_start = '================================>'
        local sep_end = '<================================'
        table.insert(result, 1, sep_start)
        table.insert(result, sep_end)

        return result
      end
    }
  }
}

M.setup = function(opts)
  default_config = vim.tbl_deep_extend("force", default_config, opts or {})
  setmetatable(M, { __index = default_config } )

  return M
end

return M
