local assert = require('luassert.assert')
local h = require('spec_helper')

--TODO: add multiple assigmnets andchar selection

describe('lua-console.utils', function()
  _G.Lua_console = {}
  local buf, config, utils

  setup(function()
    utils = require('lua-console.utils')
    config = require('lua-console.config')
    config.setup { buffer = { show_one_line_results = true } }
  end)

  before_each(function()
    buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = 'lua'
  end)

  after_each(function()
    vim.api.nvim_buf_delete(buf, { force = true })
    buf = nil
  end)

  describe('eval lua - single line', function()
    local lua_evaluator = utils.lua_evaluator
    local code, result

    it('evaluates expressions without return', function()
      code = { 'a={a=1, b=2}' }

      result = lua_evaluator(code)
      assert.has_string(result, 'nil')
    end)

    it('evaluates statements without return', function()
      code = { "string.format('[%s]', 'test')" }

      result = lua_evaluator(code)
      assert.has_string(result, '[test]')
    end)

    it('evaluates statements with return', function()
      code = { "return string.format('[%s]', 'test')" }

      result = lua_evaluator(code)
      assert.has_string(result, '[test]')
    end)

    it('fails on expressions with return', function()
      code = { 'return a={a=1, b=2}' }

      result = lua_evaluator(code)
      assert.has_string(result, "'<eof>' expected near '='")
    end)
  end)

  describe('eval lua - multiple lines', function()
    local lua_evaluator = utils.lua_evaluator
    local code, result

    it('evaluates code ending with expression', function()
      code = h.to_table([[
				local a = 10
				a = a + 5
			]])

      result = lua_evaluator(code)
      assert.has_string(result, 'nil')
    end)

    it('evaluates code ending with statement', function()
      code = h.to_table([[
				local a = 10
				a = a + 5
				a
			]])

      result = lua_evaluator(code)
      assert.has_string(result, '15')
    end)

    it('evaluates code ending with statement and return', function()
      code = h.to_table([[
				local a = 10
				a = a + 5
				return a
			]])

      result = lua_evaluator(code)
      assert.has_string(result, '15')
    end)

    it('evaluates code ending with end', function()
      code = h.to_table([[
				for i=1, 10 do
					a = i * 5
				end
			]])

      result = lua_evaluator(code)
      assert.has_string(result, 'nil')
    end)

    it('handles code that returns multiple values', function()
      code = h.to_table([[
				a = 'test_string'
				a:find('str')
			]])

      result = lua_evaluator(code)
      assert.has_string(result, '[1] 6, [2] 8')
    end)
  end)

  describe('preserving context', function()
    local lua_evaluator = utils.lua_evaluator
    local code, result, expected

    it('preserves context between executions if config is set', function()
      code = { 'a = 5' }
      lua_evaluator(code)

      code = { 'a = a + 5' }
      lua_evaluator(code)

      code = { 'a' }

      result = lua_evaluator(code)
      assert.has_string(result, '10')
    end)

    it('does not preserves context between executions if config is not set', function()
      config.setup { buffer = { preserve_context = false } }
      code = { 'a = 5' }
      lua_evaluator(code)

      code = { 'a = a + 5' }
      lua_evaluator(code)

      code = { 'a' }

      result = lua_evaluator(code)
      assert.has_string(result, 'nil')
    end)

    it('provides access to context', function()
      config.setup { buffer = { preserve_context = true, strip_local = false } }

      code = { 'test_1 = 5; b = 10; local c = 100' }
      lua_evaluator(code)

      code = { 'test_1 = test_1 + 5; b = b * 10; c = c - 50' }
      lua_evaluator(code)

      code = { '_ctx' }

      expected = h.to_string([[
				{
				  b = 100,
				  test_1 = 10
				}
			]])

      result = lua_evaluator(code)
      assert.has_string(result, expected)
    end)

    it('strips local declaration', function()
      config.setup { buffer = { preserve_context = true, strip_local = true } }

      code = { 'test_1 = 5; b = 10; local c = 100' }
      lua_evaluator(code)

      code = { 'test_1 = test_1 + 5; b = b * 10; c = c - 50' }
      lua_evaluator(code)

      code = { '_ctx' }

      expected = h.to_string([[
				{
				  b = 100,
				  c = 50,
				  test_1 = 10
				}
			]])

      result = lua_evaluator(code)
      assert.has_string(result, expected)
    end)

    it('clears context', function()
      config.setup { buffer = { preserve_context = true } }

      code = { 'test_1 = 5; b = 10; local c = 100' }
      lua_evaluator(code)

      code = { 'test_1 = test_1 + 5; b = b * 10; c = c - 50' }
      lua_evaluator(code)

      code = { '_ctx_clear()' }

      result = lua_evaluator(code)
      assert.has_string(result, 'nil')
    end)
  end)

  describe('eval lua - pretty print', function()
    local lua_evaluator = utils.lua_evaluator
    local code, result, expected

    it('pretty prints objects', function()
      code = h.to_table([[
				local ret = {}
				for i=1, 5 do
					ret[tostring(i)] = i
				end
				return ret
				]])

      expected = vim.inspect {
        ['1'] = 1,
        ['2'] = 2,
        ['3'] = 3,
        ['4'] = 4,
        ['5'] = 5,
      }

      result = lua_evaluator(code)
      assert.has_string(result, expected)
    end)

    it('pretty prints functions', function()
      code = h.to_table([[
				vim.fn.bufnr
				]])

      result = lua_evaluator(code)
      assert.has_string(result, 'short_src = "vim/_editor.lua')
    end)

    it('redirects output of print()', function()
      code = h.to_table([[
				local o = { a = 1, b = 2 }
				for i=1, 3 do
					print(i, o)
				end
			]])

      expected = [[
				[1] 1, [2] {
  				a = 1,
  				b = 2
				}
				[1] 2, [2] {
  				a = 1,
  				b = 2
				}
				[1] 3, [2] {
  				a = 1,
  				b = 2
				}
				]]

      result = lua_evaluator(code)
      assert.has_string(result, expected)
    end)
  end)

  describe('eval lua - error messages', function()
    local lua_evaluator = utils.lua_evaluator
    local code, result, expected

    it('gives an error message on syntax error', function()
      code = h.to_table([[
				for i=1, 10 do
					a = i * 5)
				end
			]])

      result = lua_evaluator(code)
      assert.has_string(result, "unexpected symbol near ')'")
    end)

    it('gives an error message on runtime error', function()
      code = h.to_table([[
				vim.fn(nil)
			]])

      result = lua_evaluator(code)
      assert.has_string(result, "attempt to call field 'fn' (a table value)")
    end)

    it('gives a clean stacktrace on runtime error', function()
      code = h.to_table([[
				vim.fs.root(nil)
			]])

      expected = [[
				vim/fs.lua:0: missing required argument: source
				stack traceback:
					[C]: in function 'assert'
					vim/fs.lua: in function <vim/fs.lua:0>]]

      result = lua_evaluator(code)

      assert.has_string(result, expected)
      assert.is_not.has_string(result, 'lua-console.nvim')
      assert.is_not.has_string(result, "[C]: in function 'xpcall'")
    end)
  end)

  describe('lua-console utils', function()
    local win

    before_each(function()
      win = vim.api.nvim_open_win(buf, true, { split = 'left' })
      _G.Lua_console = { buf = buf, win = win }
    end)

    after_each(function()
      vim.api.nvim_win_close(win, false)
      win = nil
    end)

    describe('lua_evaluator_in_buffer', function()
      local result, expected, content

      before_each(function()
        content = h.to_table([[
					{a=1, b=2}
					for i=1, 10 do
						a = i * 5
						print(i, a)
					end
					Some text here
  			]])
        h.set_buffer(buf, content)
      end)

      it('single line', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        utils.eval_code_in_buffer()

        expected = h.to_string([[
					{a=1, b=2}
					
					=> {
  					a = 1,
  					b = 2
					}
  				]])

        result = h.get_buffer(buf)
        assert.has_string(result, expected)
      end)

      it('single line - char selection', function()
        content = h.to_table([[
					Some text
					LOG(vim.bo.filetype)
					Some text
  			]])

        h.set_buffer(buf, content)

        vim.api.nvim_win_set_cursor(win, { 2, 4 })
        h.send_keys('v14l')
        utils.eval_code_in_buffer()

        result = h.get_buffer(buf)
        assert.has_string(result, 'lua')
      end)

      it('multiline', function()
        vim.api.nvim_win_set_cursor(win, { 2, 0 })
        vim.cmd.exe("'normal V3j'")

        utils.eval_code_in_buffer()

        expected = h.to_string([[
					{a=1, b=2}
					for i=1, 10 do
						a = i * 5
						print(i, a)
					end

					=> [1] 1, [2] 5
					[1] 2, [2] 10
					[1] 3, [2] 15
					[1] 4, [2] 20
					[1] 5, [2] 25
					[1] 6, [2] 30
					[1] 7, [2] 35
					[1] 8, [2] 40
					[1] 9, [2] 45
					[1] 10, [2] 50
					Some text here
  			]])

        result = h.get_buffer(buf)
        assert.has_string(result, expected)
      end)

      it('whole buffer', function()
        content = h.to_table([[
					map = {a=1, b=2}
					a = 10

					for i=1, 5 do
						print(i)
						a = a + i * 5
					end

					return a
  			]])

        h.set_buffer(buf, content)
        vim.api.nvim_win_set_cursor(win, { 5, 0 })

        utils.eval_code_in_buffer(buf, true)

        expected = h.to_string([[
					map = {a=1, b=2}
					a = 10
					
					for i=1, 5 do
					print(i)
					a = a + i * 5
					end
					
					return a
					
					=> 1
					2
					3
					4
					5
					85
  			]])

        result = h.get_buffer(buf)
        assert.has_string(result, expected)
      end)

      it('multiline expressions', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        h.send_keys('V2j')

        content = h.to_table([[
          vim.iter({ 1, 2, 3, 4, 5 }):map(function(e)
            return e
          end):totable()
  				]])

        h.set_buffer(buf, content)
        utils.eval_code_in_buffer()

        expected = config.buffer.result_prefix .. '{ 1, 2, 3, 4, 5 }'

        result = h.get_buffer(buf)
        assert.has_string(result, expected)
      end)

      it('multiline statements', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        h.send_keys('V2j')

        content = h.to_table([[
          ret = vim.iter({ 1, 2, 3, 4, 5 }):map(function(e)
            return e
          end):totable()
  				]])

        h.set_buffer(buf, content)
        utils.eval_code_in_buffer()

        expected = config.buffer.result_prefix .. '{ 1, 2, 3, 4, 5 }'

        result = h.get_virtual_text(buf, 0, 0)
        assert.has_string(result, expected)
      end)

      it('shows nil as virtual text', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        h.send_keys('V2j')

        content = h.to_table([[
					for i = 1, 5 do
						i = i + 5
					end
  				]])
        h.set_buffer(buf, content)
        utils.eval_code_in_buffer()

        expected = config.buffer.result_prefix .. 'nil'

        result = h.get_virtual_text(buf, 2, 2)
        assert.has_string(result, expected)
      end)

      it('shows value of the assignment on the last line as virtual text', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        h.send_keys('V4j')

        content = h.to_table([[
					a = 5
					for i = 1, 5 do
						i = i + 5
					end
					vim.bo.filetype = tostring(a + 5) .. 'test'
  			]])
        h.set_buffer(buf, content)
        utils.eval_code_in_buffer()

        expected = config.buffer.result_prefix .. '"10test"'

        result = h.get_virtual_text(buf, 4, 4)
        assert.has_string(result, expected)
      end)

      it('shows value of the last assignment on the corresponging line as virtual text', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        h.send_keys('V4j')

        content = h.to_table([[
					a = 5
					for i = 1, 5 do
						i = i + 5
					end
					vim.bo.filetype = tostring(a + 5) .. 'test'
  			]])
        h.set_buffer(buf, content)
        utils.eval_code_in_buffer()

        expected = config.buffer.result_prefix .. '5'

        result = h.get_virtual_text(buf)
        assert.has_string(result, expected)
      end)

      it('shows value of the multiple assignments as virtual text', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        h.send_keys('V4j')

        content = h.to_table([[
					a = 5
					for i = 1, 5 do
						i = i + 5
					end
					vim.bo.filetype, c = tostring(a + 5) .. 'test', 200
  			]])
        h.set_buffer(buf, content)
        utils.eval_code_in_buffer()

        expected = config.buffer.result_prefix .. '[1]"10test", [2] 200'

        result = h.get_virtual_text(buf)
        assert.has_string(result, expected)
      end)

      it('gives syntax error message', function()
        vim.api.nvim_win_set_cursor(win, { 1, 0 })

        content = h.to_table([[ for i, ]])
        h.set_buffer(buf, content)

        utils.eval_code_in_buffer()
        expected = h.to_string([[
          => [string "Lua console: "]:1: '<name>' expected near '<eof>'
  				]])

        result = h.get_buffer(buf)
        assert.has_string(result, expected)
      end)
    end)

    describe('lua-console.utils', function()
      local content, result, expected

      it('load_console - loads saved content into console', function()
        local path = vim.fn.stdpath('state') .. '/lua-console-test.lua'
        local file = assert(io.open(path, 'w'))

        require('lua-console.config').setup { buffer = { save_path = path } }

        content = [[
				for i=1, 10 do
					a = i * 5
				end
			]]
        file:write(content)
        file:close()

        utils.load_saved_console(buf)
        result = h.get_buffer(buf)

        assert.has_string(result, content)
      end)

      it('infers truncated paths in the stacktrace', function()
        local rtp = vim.fn.expand('$VIMRUNTIME')
        local truncated = '...e/nvim-linux64/share/nvim/runtime/lua/vim/diagnostic.lua'
        expected = rtp .. '/lua/vim/diagnostic.lua'

        local path, _ = utils.get_path_lnum(truncated)
        assert.is_same(expected, path)

        truncated = '...testing/start/lua-console.nvim/lua/lua-console/utils.lua'
        expected = h.get_root() .. '/lua/lua-console/utils.lua'

        path, _ = utils.get_path_lnum(truncated)
        assert.is_same(expected, path)
      end)

      it('infers truncated paths and line number in the stacktrace', function()
        local truncated = '...testing/start/lua-console.nvim/lua/lua-console/utils.lua'
        content = h.to_table([[
      		'...testing/start/lua-console.nvim/lua/lua-console/utils.lua:85'
				]])
        h.set_buffer(buf, content)
        vim.api.nvim_win_set_cursor(win, { 1, 0 })

        expected = h.get_root() .. '/lua/lua-console/utils.lua'

        local path, lnum = utils.get_path_lnum(truncated)
        assert.is_same(expected, path)
        assert.is_same(85, lnum)
      end)

      it('get_source_lnum - gets the line number for function source', function()
        content = h.to_table([[
				=> {
  				currentline = -1,
  				func = <function 1>,
  				isvararg = false,
  				lastlinedefined = 129,
  				linedefined = 125,
  				namewhat = "",
  				nparams = 0,
  				nups = 1,
  				short_src = ".../.local/share/nvim/lazy/arrow.nvim/lua/arrow/persist.lua",
  				source = "@/home/yaro/.local/share/nvim/lazy/arrow.nvim/lua/arrow/persist.lua",
  				what = "Lua"
				}
			]])
        h.set_buffer(buf, content)
        vim.api.nvim_win_set_cursor(win, { 11, 0 })

        local truncated = '.../.local/share/nvim/lazy/arrow.nvim/lua/arrow/persist.lua'
        local _, lnum = utils.get_path_lnum(truncated)
        assert.equals(125, lnum)
      end)

      pending('load_messages - into console', function()
        content = h.to_string('Message 1 Message 2 Message 3')
        vim.cmd("echomsg '" .. content .. "'")

        utils.load_messages()

        result = h.get_buffer(buf)
        assert.has_string(result, content)
      end)
    end)
  end)
end)
