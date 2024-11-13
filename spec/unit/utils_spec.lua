local h = require("spec_helper")

describe("lua-console.utils", function()
	local utils

	setup(function()
		utils = require("lua-console.utils")
		require('lua-console.config').setup()
	end)

	describe("eval lua - single line", function()
		local eval_lua = utils.eval_lua
		local code, result

		it("evaluates expressions without return", function()
			code = { "a={a=1, b=2}" }

			result = eval_lua(code)
			assert.has_string(result, "nil")
		end)

		it("evaluates statements without return", function()
			code = { "vim.fn.stdpath('config')" }

			result = eval_lua(code)
			assert.has_string(result, "spec/xdg/config")
		end)

		it("evaluates statements with return", function()
			code = { "return vim.fn.stdpath('config')" }

			result = eval_lua(code)
			assert.has_string(result, "spec/xdg/config")
		end)

		it("fails on expressions with return", function()
			code = { "return a={a=1, b=2}" }

			result = eval_lua(code)
			assert.has_string(result, "'<eof>' expected near '='")
		end)

	end)

	describe('eval lua - multiple lines', function()
		local eval_lua = utils.eval_lua
		local code, result

		it("evaluates code ending with expression", function()
			code = h.to_table([[
				local a = 10
				a = a + 5
			]])

			result = eval_lua(code)
			assert.has_string(result, "nil")
		end)

		it("evaluates code ending with statement", function()
			code = h.to_table([[
				local a = 10
				a = a + 5
				a
			]])

			result = eval_lua(code)
			assert.has_string(result, "15")
		end)

		it("evaluates code ending with statement and return", function()
			code = h.to_table([[
				local a = 10
				a = a + 5
				return a
			]])

			result = eval_lua(code)
			assert.has_string(result, "15")
		end)

		it("evaluates code ending with end", function()
			code = h.to_table([[
				for i=1, 10 do
					a = i * 5
				end
			]])

			result = eval_lua(code)
			assert.has_string(result, "nil")
		end)
	end)

	describe("eval lua - pretty print", function()
		local eval_lua = utils.eval_lua
		local code, result, expected

		it("pretty prints objects", function()
			code = h.to_table([[
				local ret = {}
				for i=1, 5 do
					ret[tostring(i)] = i
				end
				return ret
				]])

			expected = vim.inspect({
				["1"] = 1,
				["2"] = 2,
				["3"] = 3,
				["4"] = 4,
				["5"] = 5,
			})

			result = eval_lua(code)
			assert.has_string(result, expected)
		end)

		it("pretty prints functions", function()
			code = h.to_table([[
				vim.fn.bufnr
				]])

			result = eval_lua(code)
			assert.has_string(result, 'short_src = "vim/_editor.lua')
		end)

		it("redirects output of print()", function()
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
				nil]]

			result = eval_lua(code)
			assert.has_string(result, expected)
		end)
	end)

	describe("eval lua - error messages", function()
		local eval_lua = utils.eval_lua
		local code, result, expected

		it("gives an error message on syntax error", function()
			code = h.to_table([[
				for i=1, 10 do
					a = i * 5)
				end
			]])

			result = eval_lua(code)
			assert.has_string(result, "unexpected symbol near ')'")
		end)

		it("gives an error message on runtime error", function()
			code = h.to_table([[
				vim.fn(nil)
			]])

			result = eval_lua(code)
			assert.has_string(result, "attempt to call field 'fn' (a table value)")
		end)

		it("gives a stacktrace on runtime error", function()
			code = h.to_table([[
				vim.fs.root(nil)
			]])

			expected = [[
				vim/fs.lua:0: missing required argument: source
				stack traceback:
					[C]: in function 'assert'
					vim/fs.lua: in function <vim/fs.lua:0>]]

			result = eval_lua(code)

			assert.has_string(result, expected)
			assert.is_not.has_string(result, "lua-console.nvim")
			assert.is_not.has_string(result, "[C]: in function 'xpcall'")
		end)
	end)

	describe("lua-console utils", function()
		local buf, win

		before_each(function()
			buf = vim.api.nvim_create_buf(true, true)
			win = vim.api.nvim_open_win(buf, true, { split = "left" })
			_G.Lua_console = { buf = buf, win = win }
		end)

		after_each(function()
			vim.api.nvim_win_close(win, false)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		describe("eval_lua_in_buffer", function()
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

			it("evaluates lua in current buffer - single line", function()
				vim.api.nvim_win_set_cursor(win, { 1, 0 })
				utils.eval_lua_in_buffer()

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

			it("evaluates lua in current buffer - multiline", function()
				vim.api.nvim_win_set_cursor(win, { 2, 0 })
				vim.cmd.exe("'normal V3j'")

				utils.eval_lua_in_buffer()

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
					nil
					Some text here
  			]])

				result = h.get_buffer(buf)
				assert.has_string(result, expected)
			end)
		end)

		describe("lua-console.utils", function()
			local content, result

			it("load_console - loads saved content into console", function()
				local path = require("lua-console.config").buffer.save_path
				local file = assert(io.open(path, "w"))

				content = [[
				for i=1, 10 do
					a = i * 5
				end
			]]
				file:write(content)
				file:close()

				utils.load_console()
				result = h.get_buffer(buf)

				assert.has_string(result, content)
			end)

			it("get_source_lnum - get the line number for function source", function()
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

				result = utils.get_source_lnum()
				assert.equals(125, result)
			end)

			it("load_messages - into console", function()
				content = h.to_string("Message 1 Message 2 Message 3")
				vim.cmd("echomsg '" .. content .. "'")

				utils.load_messages()

				result = h.get_buffer(buf)
				assert.has_string(result, content)
			end)
		end)
	end)
end)
