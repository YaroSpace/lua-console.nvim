local M = {}

local config = require('lua-console.config')
local utils = require('lua-console.utils')

local function set_map(buf, map, opts, mode)
  if not map then return end
  mode = mode or 'n'
  opts.buffer = buf

  vim.keymap.set(mode, map, '', opts)
end

M.set_global_mappings = function()
  local console = require('lua-console')
  local m = config.mappings

  set_map(nil, m.toggle, {
    callback = console.toggle_console,
    desc = 'Toggle Lua console',
  })

  set_map(nil, m.attach, {
    callback = function()
      utils.attach_toggle()
    end,
    desc = 'Attach Lua console to buffer',
  })
end

M.set_console_commands = function()
  local function complete()
    return { 'AttachToggle' }
  end

  vim.api.nvim_create_user_command('LuaConsole', function(data)
    local command = data.args

    if command == 'AttachToggle' then utils.attach_toggle() end
  end, { nargs = 1, force = true, desc = 'Lua console commands', complete = complete })
end

M.set_console_mappings = function(buf)
  local m = config.mappings

  set_map(buf, m.resize_up, {
    desc = 'Resize up',
    callback = function()
      vim.cmd.resize('+5')
    end,
  })

  set_map(buf, m.resize_down, {
    desc = 'Resize down',
    callback = function()
      vim.cmd.resize('-5')
    end,
  })

  set_map(buf, m.messages, {
    desc = 'Load messages',
    callback = function()
      utils.load_messages(buf)
    end,
  })

  set_map(buf, m.save, {
    desc = 'Save console',
    callback = function()
      local contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      vim.fn.writefile(contents, config.buffer.save_path)
      vim.notify('Lua console saved', vim.log.levels.INFO)
    end,
  })

  set_map(buf, m.load, {
    desc = 'Load saved console',
    callback = function()
      utils.load_saved_console(buf)
      utils.toggle_help(buf)
      vim.notify('Lua console loaded', vim.log.levels.INFO)
    end,
  })

  set_map(buf, m.quit, {
    desc = 'Hide console',
    callback = function()
      vim.api.nvim_win_close(0, false)
    end,
  })

  set_map(buf, m.help, {
    desc = 'Toggle help',
    callback = function()
      utils.toggle_help(buf)
    end,
  })
end

M.set_evaluator_mappings = function(buf, toggle)
  local m = config.mappings

  if not toggle then
    vim.keymap.del('n', m.eval, { buffer = buf })
    vim.keymap.del('n', m.eval_buffer, { buffer = buf })
    vim.keymap.del('n', m.open, { buffer = buf })

    return
  end

  set_map(buf, m.open, {
    desc = 'Opens file in vertical split',
    callback = function()
      local path, lnum = utils.get_path_lnum(vim.fn.expand('<cfile>'))
      path = vim.startswith(path, '~') and vim.fn.expand(path) or path

      if vim.fn.filereadable(path) == 0 then return end

      local win = vim.fn.bufwinid(buf)
      if win == _G.Lua_console.win then vim.api.nvim_win_close(win, false) end

      vim.cmd('vs ' .. path)
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    end,
  })

  set_map(buf, m.eval, {
    desc = 'Eval code in current line or visual selection',
    callback = function()
      utils.eval_code_in_buffer(buf)
    end,
  }, { 'n', 'v' })

  set_map(buf, m.eval_buffer, {
    desc = 'Eval code in current buffer',
    callback = function()
      utils.eval_code_in_buffer(buf, true)
    end,
  }, 'n')
end

M.set_console_autocommands = function(buf)
  vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWinLeave' }, {
    buffer = buf,
    desc = 'Close window when focus is lost',
    callback = function()
      local lc = _G.Lua_console
      local win = lc.win

      if config.buffer.autosave then
        local contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        vim.fn.writefile(contents, config.buffer.save_path)
      end

      if not win then return end

      if vim.api.nvim_win_is_valid(win) then
        lc.height = vim.api.nvim_win_get_height(win)
        vim.api.nvim_win_close(win, false)
      end

      lc.win = false
    end,
  })
end

return M
