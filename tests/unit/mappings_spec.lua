local assert = require('luassert.assert')
local h = require('spec_helper')

describe('lua-console.nvim - mappings', function()
  local console, config, mappings, utils
  local buf, win
  local content, expected, result

  before_each(function()
    mappings = {
      toggle = '&&',
      attach = '@@',
      quit = 'qq',
      eval = '$$',
      open = 'ff',
      messages = 'M',
      save = 'S',
      load = 'L',
      resize_up = 'gq',
      resize_down = 'gw',
      help = 'g?',
    }

    console = require('lua-console')
    utils = require('lua-console.utils')

    config = require('lua-console').setup {
      mappings = mappings,
      buffer = {
        load_on_start = false,
        save_path = vim.fn.stdpath('state') .. '/lua-console-test.lua',
        show_one_line_results = true,
      },
    }

    mappings = config.mappings
    console.toggle_console()

    buf = vim.fn.bufnr('lua-console')
    win = vim.fn.bufwinid(buf)

    content = h.to_table([[
          for i=1, 3 do
          	print(i, 'A-' .. i*10)
          end
			  ]])

    h.set_buffer(buf, content)
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end)

  after_each(function()
    h.delete_all_bufs()
    require('lua-console').deactivate()
    buf, win = nil, nil
  end)

  describe('sets global mappings', function()
    it('toggles console - on', function()
      h.delete_buffer(buf)
      h.send_keys(mappings.toggle)
      buf = vim.fn.bufnr('lua-console')

      assert.is_same(_G.Lua_console.buf, buf)
    end)

    it('toggles console - off', function()
      h.send_keys(mappings.toggle)
      assert.is_same(_G.Lua_console.win, false)
    end)

    it('attaches to buffer', function()
      buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_set_current_buf(buf)
      h.send_keys(mappings.attach)

      local maps = h.get_maps(buf)

      assert.is.not_nil(maps[mappings.eval])
      assert.is.not_nil(maps[mappings.eval_buffer])
      assert.is.not_nil(maps[mappings.open])
    end)

    it('LuaConsole toggle command attaches to buffer', function()
      buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_set_current_buf(buf)
      vim.cmd('LuaConsole AttachToggle')

      local maps = h.get_maps(buf)

      assert.is.not_nil(maps[mappings.eval])
    end)

    it('LuaConsole toggle command dettaches', function()
      buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_set_current_buf(buf)

      vim.cmd('LuaConsole AttachToggle')
      vim.cmd('LuaConsole AttachToggle')

      local maps = h.get_maps(buf)

      assert.is_nil(maps[mappings.eval])
    end)
  end)

  describe('lua-console.nvim - mappings', function()
    it('resizes window up', function()
      local height = vim.api.nvim_win_get_height(win)

      h.send_keys(mappings.resize_up)
      result = vim.api.nvim_win_get_height(win)

      assert.are_same(height + 5, result)
    end)

    it('resizes window down', function()
      local height = vim.api.nvim_win_get_height(win)

      h.send_keys(mappings.resize_down)
      result = vim.api.nvim_win_get_height(win)

      assert.are_same(height - 5, result)
    end)

    it('quits console', function()
      h.send_keys(mappings.quit)
      win = vim.fn.bufwinid(buf)

      assert.are_same(-1, win)
    end)

    it('evaluates code', function()
      h.send_keys('V2j' .. mappings.eval)
      result = h.get_buffer(buf)

      expected = [[
				=> [1] 1, [2] "A-10"
				[1] 2, [2] "A-20"
				[1] 3, [2] "A-30"
			]]

      assert.has_string(result, expected)
    end)

    it('saves console', function()
      content = h.to_table([[
				Some text 1
				Some text 2
				Some text 3
			]])
      h.set_buffer(buf, content)

      h.send_keys(mappings.save)
      result = h.get_buffer(buf)

      local file = io.open(config.buffer.save_path):read('*all')
      assert.has_string(result, file)
    end)

    it('loads console', function()
      content = h.to_table([[
				Some new text 10
				Some new text 11
				Some new text 12
			]])
      h.set_buffer(buf, content)

      h.send_keys(mappings.save)
      h.send_keys('ggdG')
      h.send_keys(mappings.load)

      result = h.get_buffer(buf)
      assert.has_string(result, h.to_string(content))

      result = h.get_virtual_text(buf, 0)
      assert.has_string(result, config.mappings.help .. ' - help')
    end)

    it('toggles help message - on', function()
      vim.api.nvim_buf_delete(vim.fn.bufnr(buf), { force = true })

      console.toggle_console()
      buf = vim.fn.bufnr('lua-console')

      h.send_keys(mappings.help)

      result = h.get_virtual_text(buf)
      assert.has_string(result, config.mappings.eval .. ' - eval a line or selection')
    end)

    it('toggles help message - off', function()
      vim.api.nvim_buf_delete(vim.fn.bufnr(buf), { force = true })
      console.toggle_console()
      buf = vim.fn.bufnr('lua-console')

      h.send_keys(mappings.help)
      h.send_keys(mappings.help)

      result = h.get_virtual_text(buf, 0)
      assert.has_string(result, config.mappings.help .. ' - help')
    end)

    it('opens a split with file from function definition', function()
      content = h.to_table([[
          require("lua-console").toggle_console
          Test
			  ]])
      h.set_buffer(buf, content)

      h.send_keys(config.mappings.eval)
      vim.api.nvim_win_set_cursor(win, { 13, 20 })
      h.send_keys(config.mappings.open)

      local new_buf = vim.fn.bufnr()
      assert.has_string(vim.fn.bufname(new_buf), 'lua/lua-console.lua')

      local line = vim.fn.line('.')
      assert.is_same(line, 69)
    end)

    it('opens a split with file from stacktrace', function()
      content = h.to_table([[
  			vim.lsp.diagnostic.get_namespace(nil)
			]])
      h.set_buffer(buf, content)

      h.send_keys(config.mappings.eval)
      result = h.get_buffer(buf)

      vim.api.nvim_win_set_cursor(win, { 7, 0 })
      h.send_keys(config.mappings.open)

      local new_buf = vim.fn.bufnr()
      local path = vim.fn.expand('$VIMRUNTIME') .. '/lua/vim/lsp/diagnostic.lua'
      assert.has_string(vim.fn.bufname(new_buf), path)

      local line = vim.fn.line('.')
      assert.is_same(line, 173)
    end)

    it('sets autocommand to close window on lost focus', function()
      vim.cmd('ene')

      win = vim.fn.winbufnr(buf)
      assert.are_same(win, -1)
      assert.is_false(_G.Lua_console.win)
    end)

    it('sets autocommand to remember height on win close', function()
      result = vim.api.nvim_win_get_height(win)
      vim.cmd('ene')

      assert.are_same(result, _G.Lua_console.height)
    end)
  end)

  describe('attaches to a buffer', function()
    local other_buf

    before_each(function()
      other_buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_set_current_buf(other_buf)
      vim.bo[other_buf].filetype = 'lua'

      utils.attach_toggle(other_buf)
    end)

    --TODO: finish spec
    it('cretes mappings for attached buffer', function()
      -- code
    end)

    it('evaluates code', function()
      content = h.to_table([[
				a = 'test_string'
				a:find('str')
			]])
      h.set_buffer(other_buf, content)
      vim.fn.cursor(1, 0)

      h.send_keys('V1j' .. config.mappings.eval)

      result = h.get_buffer(other_buf)
      assert.has_string(result, '[1] 6, [2] 8')
    end)

    it('follows links', function()
      content = h.to_table([[
  			vim.lsp.diagnostic.get_namespace(nil)
			]])
      h.set_buffer(other_buf, content)

      h.send_keys(config.mappings.eval)
      result = h.get_buffer(other_buf)

      vim.fn.cursor(7, 0)
      h.send_keys(config.mappings.open)

      local new_buf = vim.fn.bufnr()
      local path = vim.fn.expand('$VIMRUNTIME') .. '/lua/vim/lsp/diagnostic.lua'
      assert.has_string(vim.fn.bufname(new_buf), path)

      local line = vim.fn.line('.')
      assert.is_same(line, 173)
    end)

    it('preserves context', function()
      content = h.to_table([[
        a = 5
        a = a + 5
        a
      ]])
      h.set_buffer(other_buf, content)

      vim.fn.cursor(1, 0)
      h.send_keys(config.mappings.eval)

      vim.fn.cursor(2, 0)
      h.send_keys(config.mappings.eval)

      vim.fn.cursor(3, 0)
      h.send_keys(config.mappings.eval)

      result = h.get_buffer(other_buf)

      assert.has_string(result[#result], '10')
    end)

    it('dettaches if already attached', function()
      -- code
    end)

    --TODO: finish spec
    it('removes mappings for dettached buffer', function()
      -- code
    end)
  end)
end)
