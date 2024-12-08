local assert = require('luassert.assert')
local h = require('spec_helper')

describe('lua-console.nvim', function()
  local buf, win, lc
  local console, config
  local expected, result

  before_each(function()
    local path = vim.fn.stdpath('state') .. '/lua-console-test.lua'

    console = require('lua-console')
    config = console.setup { buffer = { save_path = path } }
    lc = _G.Lua_console
  end)

  after_each(function()
    require('lua-console').deactivate()
    buf, win = nil, nil
  end)

  describe('lua-console.nvim - setup', function()
    it('sets up with custom config', function()
      config = {
        buffer = {
          result_prefix = '$$ ',
        },
        window = {
          border = 'single',
        },
        mappings = {
          toggle = '!#',
          attach = '!`',
          eval = '$#',
        },
      }

      console.setup(config)
      result = require('lua-console.config')

      assert.has_properties(result, config)
    end)

    it('sets a mapping for toggling the console', function()
      local maps = h.get_maps(buf)
      assert.is.not_nil(maps['!#'])
    end)

    it('sets a mapping for attaching to buffer', function()
      local maps = h.get_maps(buf)
      assert.is.not_nil(maps['!`'])
    end)

    describe('lua-console - open/close window', function()
      before_each(function()
        console.toggle_console()
        buf = vim.fn.bufnr('lua-console')
        win = vim.fn.bufwinid(buf)
      end)

      after_each(function() end)

      it('opens console if it is closed', function()
        assert.are_not.same(buf, -1)
        assert.are_same(lc.buf, buf)

        assert.are_not.same(win, -1)
        assert.are_same(lc.win, win)
      end)

      it('closes console window if it is open', function()
        console.toggle_console()

        win = vim.fn.bufwinid(buf)

        assert.are_not.same(buf, -1)
        assert.are_same(win, -1)
        assert.is_false(lc.win)
      end)

      it('creates a buffer with correct properties', function()
        expected = {
          swapfile = false,
          buflisted = false,
          bufhidden = 'hide',
          buftype = 'nowrite',
          filetype = 'lua',
        }
        result = vim.bo[buf]
        assert.has_properties(result, expected)

        result = vim.fn.bufname(buf)
        local path = h.get_root() .. '/console'
        assert.are_same(result, path)
      end)

      it('creates a new buffer if there is one already, but unloaded', function()
        vim.api.nvim_buf_delete(buf, { unload = true })

        console.toggle_console()
        local new_buf = vim.fn.bufnr('lua-console')

        assert.are_not.same(buf, new_buf)
      end)

      it('sets default key mappings for the buffer', function()
        local mappings = config.mappings
        mappings.toggle = nil
        mappings.attach = nil

        local maps = h.get_maps(buf)

        for key, map in pairs(mappings) do
          assert.is.not_nil(maps[map], 'Mapping not found for: ' .. key)
        end
      end)

      it('sets custom key mappings for the buffer', function()
        h.delete_buffer(buf)

        local mappings = {
          mappings = {
            quit = 'qq',
            eval = '$$',
            open = 'ff',
            messages = 'M',
            save = 'S',
            load = 'L',
            resize_up = 'gq',
            resize_down = 'gw',
            help = 'g?',
          },
        }

        console.setup(mappings)
        console.toggle_console()
        buf = vim.fn.bufnr('lua-console')

        local maps = h.get_maps(buf)

        for _, map in pairs(mappings.mappings) do
          assert.is.not_nil(maps[map], 'Mapping not found: ' .. map)
        end
      end)

      it('creates a window with correct properties', function()
        expected = {
          foldcolumn = 'auto:9',
          cursorline = true,
          foldmethod = 'indent',
          winbar = '',
        }
        assert.has_properties(vim.wo[win], expected)
      end)

      it('creates a window with correct config', function()
        expected = config.window
        expected.style = nil
        expected.title = nil
        expected.height = nil
        expected.border = nil

        result = vim.api.nvim_win_get_config(win)
        assert.has_properties(result, expected)
      end)

      it('shows help message on start', function()
        result = h.get_virtual_text(buf, 0)
        assert.has_string(result, config.mappings.help .. ' - help')
      end)

      describe('save/load operations', function()
        after_each(function()
          os.remove(config.buffer.save_path)
        end)

        it('autosaves content when console window is closed', function()
          local content = h.to_table([[ Some code ]])
          h.set_buffer(buf, content)

          vim.api.nvim_win_close(win, true)
          result = vim.fn.readfile(config.buffer.save_path)

          assert.has_string(result, content)
        end)

        it('autosaves content when console buffer is closed', function()
          local content = h.to_table([[ Some code other ]])
          h.set_buffer(buf, content)

          vim.api.nvim_buf_delete(buf, { force = true })
          result = vim.fn.readfile(config.buffer.save_path)

          assert.has_string(result, content)
        end)

        it('it loads saved content on startup', function()
          vim.api.nvim_buf_delete(vim.fn.bufnr(buf), { force = true })

          local content = h.to_table([[
				    for i=1, 10 do
					    a = i * 5
				    end
			    ]])
          vim.fn.writefile(content, config.buffer.save_path)

          console.toggle_console()
          buf = vim.fn.bufnr('lua-console')

          result = h.get_buffer(buf)
          assert.has_string(result, content)
        end)
      end)
    end)
  end)
end)
