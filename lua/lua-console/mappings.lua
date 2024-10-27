local M = {}

local config = require('lua-console.config')
local utils = require('lua-console.utils')

M.set_buf_keymap = function()
  --- @type number
  local buf = Lua_console.buf

  vim.api.nvim_buf_set_keymap(buf, "n", "<C-Up>", "", {
    desc = "Resize up",
    callback = function()
      vim.cmd.resize('+5')
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<C-Down>", "", {
    desc = "Resize down",
    callback = function()
      vim.cmd.resize('-5')
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "k", "", {
    desc = "Move up",
    callback = function()
      if vim.api.nvim_win_get_cursor(0)[1] == 2 then return end
      vim.api.nvim_feedkeys('k', 'n', false)
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", config.mappings.clear, "", {
    desc = 'Clear console',
    callback = function() vim.api.nvim_buf_set_lines(0, 1, -1, false, {''}) end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", config.mappings.messages, "", {
    desc = 'Load messages',
    callback = utils.load_messages
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "gf", "", {
    desc = "Open file in vertical split",
    callback = function()
      local file = vim.fn.expand "<cfile>"
      local line = utils.get_file_line()

      vim.api.nvim_win_close(0, false)

      vim.cmd("vs " .. file)
      if line then vim.api.nvim_win_set_cursor(0, {line, 0}) end
    end,
  })

  vim.keymap.set({"n", "v"}, config.mappings.eval, "", {
    buffer = buf,
    desc = "Eval lua code in current line or visual selection",
    callback = utils.eval_lua_in_buffer
  })

  vim.keymap.set({"n"}, config.mappings.save, "", {
    buffer = buf,
    desc = "Save console",
    callback = function()
      vim.cmd('write! ' .. config.buffer.save_path)
    end
  })

  vim.keymap.set({"n"}, config.mappings.load, "", {
    buffer = buf,
    desc = "Load console",
    callback = utils.load_console
  })

  vim.keymap.set({"n"}, 'q', "", {
    buffer = buf,
    desc = "Close console",
    callback = function()
      vim.api.nvim_win_close(0, false)
    end
  })
end

M.set_buf_autocommands = function()
  vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
    buffer = Lua_console.buf,
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
