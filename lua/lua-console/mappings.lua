local M = {}

M.set_buf_keymap = function(buf)
  local utils = require('lua-console.utils')
  local config = require('lua-console.config')
  local mappings = config.mappings

  vim.api.nvim_buf_set_keymap(buf, "n", mappings.resize_up, "", {
    desc = "Resize up",
    callback = function()
      vim.cmd.resize('+5')
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", mappings.resize_down, "", {
    desc = "Resize down",
    callback = function()
      vim.cmd.resize('-5')
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", mappings.clear, "", {
    desc = 'Clear console',
    callback = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {''})
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", mappings.messages, "", {
    desc = 'Load messages',
    callback = utils.load_messages
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "gf", "", {
    desc = "Opens file in vertical split",
    callback = function()
      local path, lnum = utils.get_path_lnum(vim.fn.expand "<cfile>")
      if vim.fn.filereadable(path) == 0 then return end

      vim.api.nvim_win_close(0, false)
      vim.cmd("vs " .. path)
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    end,
  })

  vim.keymap.set({"n", "v"}, mappings.eval, "", {
    buffer = buf,
    desc = "Eval lua code in current line or visual selection",
    callback = utils.eval_code_in_buffer
  })

  vim.keymap.set({"n"}, mappings.save, "", {
    buffer = buf,
    desc = "Save console",
    callback = function()
      vim.cmd('write! ' .. config.buffer.save_path)
    end
  })

  vim.keymap.set({"n"}, mappings.load, "", {
    buffer = buf,
    desc = "Load console",
    callback = function()
      utils.load_saved_console(buf)
      utils.toggle_help(buf)
    end
  })

  vim.keymap.set({"n"}, mappings.quit, "", {
    buffer = buf,
    desc = "Close console",
    callback = function()
      vim.api.nvim_win_close(0, false)
    end
  })

  vim.keymap.set({"n"}, mappings.help, "", {
    buffer = buf,
    desc = "Toggle help",
    callback = function()
      utils.toggle_help(buf)
    end
  })
end

M.set_buf_autocommands = function(buf)
  vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
    buffer = buf,
    desc = "Close window when focus is lost",
    callback = function()
      local win = Lua_console.win
      if not win then return end

      if vim.api.nvim_win_is_valid(win) then
        Lua_console.height = vim.api.nvim_win_get_height(win)
        vim.api.nvim_win_close(win, false)
      end

      Lua_console.win = false
    end
  })
end

return M
