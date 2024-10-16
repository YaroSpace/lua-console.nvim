local M = {}

local config = require('lua-console.config')
local utils = require('lua-console.utils')


M.set_buf_keymap = function(buf)
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-Up>", ":resize +5<cr>", { desc = "Resize window" })
  vim.api.nvim_buf_set_keymap(buf, "n", "<C-Down>", ":resize -5<cr>", { desc = "Resize window" })

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
    callback = function()
      local messages = vim.api.nvim_exec2('messages', { output = true }).output
      utils.append_current_buffer(messages)
    end
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "gf", "", {
    desc = "Open file in vertical split",
    callback = function()
      local file = vim.fn.expand "<cfile>"
      vim.api.nvim_win_close(0, false)
      vim.cmd("vs " .. file)
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
      local path = vim.fn.stdpath('state') .. '/lua-console.lua'
      vim.cmd('write! ' .. path)
    end
  })

  vim.keymap.set({"n"}, config.mappings.load, "", {
    buffer = buf,
    desc = "Load console",
    callback = function()
      local path = vim.fn.stdpath('state') .. '/lua-console.lua'
      if vim.fn.filereadable(path) == 0 then return end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      vim.cmd(':0read ' .. path)
    end
  })
end

M.set_buf_autocommands = function(buf)
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    desc = "Close window when focus is lost",
    callback = function() vim.api.nvim_win_close(0, false) end
  })
end

return M
