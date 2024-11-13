local h = require('spec_helper')

describe('lua-console.nvim', function()
  local buf, win
  local console, config
  local expected, result

  before_each(function()
    console = require('lua-console')
    config = require('lua-console').setup()
  end)

  after_each(function()
    require('lua-console').deactivate()
		buf, win = nil, nil
  end)

  describe('lua-console.nvim - setup', function()
    it('sets up with custom config', function()
      config = {
        buffer = {
          prepend_result_with = '$$ ',
        },
        window = {
          border = 'single',
        },
        mappings = {
          toggle = '!',
          eval = 'GG',
        },
      }

      console.setup(config)
      result = require('lua-console.config')

      console.toggle_console()

      assert.has_properties(result, config)
      assert.has_no.errors(function()
        vim.keymap.del('n', config.mappings.eval, { buffer = Lua_console.buf })
      end)
    end)

    it('sets a mapping for toggling the console', function()
      assert.has_no.errors(function()
        vim.keymap.del('n', config.mappings.toggle)
      end)
    end)

    describe('lua-console - open/close window', function()
      before_each(function()
        console.toggle_console()
        buf = vim.fn.bufnr('lua-console')
        win = vim.fn.bufwinid(buf)
      end)

      after_each(function()
        buf = nil
        win = nil
      end)

      it('opens console if it is closed', function()
        assert.are_not.same(buf, -1)
        assert.are_same(Lua_console.buf, buf)

        assert.are_not.same(win, -1)
        assert.are_same(Lua_console.win, win)
      end)

      it('closes console window if it is open', function()
        console.toggle_console()

        win = vim.fn.bufwinid(buf)

        assert.are_not.same(buf, -1)
        assert.are_same(win, -1)
        assert.is_false(Lua_console.win)
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
        local path = vim.fn.expand('$XDG_PLUGIN_PATH') .. '/console'
        assert.are_same(result, path)
      end)

      it('creates a new buffer if there is one already, but unloaded', function()
        vim.api.nvim_buf_delete(buf, { unload = true })

        console.toggle_console()
        local new_buf = vim.fn.bufnr('lua-console')

        assert.are_not.same(buf, new_buf)
      end)

      it('sets key mappings for the buffer', function()
        local mappings = config.mappings
        mappings.toggle = nil

        for _, map in pairs(mappings) do
          assert.has_no.errors(function()
            vim.keymap.del('n', map, { buffer = buf })
          end)
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
        assert.has_string(result, config.mappings.help .. ' - help' )
      end)

      it('it loads saved content on startup', function()
        vim.api.nvim_buf_delete(vim.fn.bufnr(buf), { force = true })

        local path = config.buffer.save_path
        local file = assert(io.open(path, 'w'))

        local content = [[
				for i=1, 10 do
					a = i * 5
				end
			]]
        file:write(content)
        file:close()

        console.toggle_console()
        buf = vim.fn.bufnr('lua-console')

        result = h.get_buffer(buf)
        assert.has_string(result, content)
      end)
    end)
  end)
end)
