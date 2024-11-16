local h = require("spec_helper")

describe("lua-console.nvim - mappings", function()
	local console, config, mappings
	local buf, win
	local content, expected, result

	before_each(function()
		mappings = {
			toggle = "`",
			quit = "q",
			eval = "$$",
			clear = "C",
			messages = "M",
			save = "S",
			load = "L",
			resize_up = "gq",
			resize_down = "gw",
			help = 'g?'
		}

		console = require("lua-console")
		config = require("lua-console").setup({ mappings = mappings })
		mappings = config.mappings
		console.toggle_console()

		buf = vim.fn.bufnr("lua-console")
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
		require("lua-console").deactivate()
		for _, no in ipairs(vim.api.nvim_list_bufs()) do
			vim.api.nvim_buf_delete(no, { force = true })
		end
		buf, win = nil, nil
	end)

	describe("lua-console.nvim - mappings", function()
		it("resizes window up", function()
			local height = vim.api.nvim_win_get_height(win)

			h.send_keys(mappings.resize_up)
			result = vim.api.nvim_win_get_height(win)

			assert.are_same(height + 5, result)
		end)

		it("resizes window down", function()
			local height = vim.api.nvim_win_get_height(win)

			h.send_keys(mappings.resize_down)
			result = vim.api.nvim_win_get_height(win)

			assert.are_same(height - 5, result)
		end)

		it("quits console", function()
			h.send_keys(mappings.quit)
			win = vim.fn.bufwinid(buf)

			assert.are_same(-1, win)
		end)

		it("evaluates code", function()
			h.send_keys("V2j" .. mappings.eval)
			result = h.get_buffer(buf)

			expected = [[
				=> [1] 1, [2] "A-10"
				[1] 2, [2] "A-20"
				[1] 3, [2] "A-30"
				nil
			]]

			assert.has_string(result, expected)
		end)

		it("clears console", function()
			h.send_keys(mappings.clear)
			result = h.get_buffer(buf)

			assert.is_not.has_string(result, "print(i, 'A-' .. i*10)")
		end)

		pending("loads messages", function() -- test fails with segmentation fault: weird
			content = h.to_string("Message 1 Message 2 Message 3")
			vim.cmd("echomsg '" .. content .. "'")

			h.send_keys(mappings.messages)
			result = h.get_buffer(buf)

			assert.has_string(result, content)
		end)

		it("saves console", function()
			content = h.to_table([[
				Some text 1
				Some text 2
				Some text 3
			]])
			h.set_buffer(buf, content)

			h.send_keys(mappings.save)
			result = h.get_buffer(buf)

			local file = io.open(config.buffer.save_path)
			assert.has_string(result, file:read())
		end)

		it("loads console", function()
			content = h.to_table([[
				Some new text 1
				Some new text 2
				Some new text 3
			]])
			h.set_buffer(buf, content)

			h.send_keys(mappings.save)
			h.send_keys(mappings.clear)
			h.send_keys(mappings.load)

			result = h.get_buffer(buf)
			assert.has_string(result, h.to_string(content))

			result = h.get_virtual_text(buf, 0)
			assert.has_string(result, config.mappings.help .. ' - help')
		end)

		it("toggles help message", function()
			vim.api.nvim_buf_delete(vim.fn.bufnr(buf), { force = true })

			console.toggle_console()
			buf = vim.fn.bufnr("lua-console")

			h.send_keys(mappings.help)

			result = h.get_virtual_text(buf)
			assert.has_string(result, "'" .. config.mappings.eval .. "' - eval a line or selection")
		end)

		it("toggles help message", function()
			vim.api.nvim_buf_delete(vim.fn.bufnr(buf), { force = true })
			console.toggle_console()
			buf = vim.fn.bufnr("lua-console")

			h.send_keys(mappings.help)
			h.send_keys(mappings.help)

			result = h.get_virtual_text(buf, 0)
			assert.has_string(result, config.mappings.help .. " - help")
		end)

		it("opens a split with file from function definition", function()
			content = h.to_table([[
          vim.lsp.status
          Test
			  ]])
			h.set_buffer(buf, content)

			h.send_keys(config.mappings.eval)
			vim.api.nvim_win_set_cursor(win, { 13, 20 })
			h.send_keys("gf")

			local new_buf = vim.fn.bufnr()
			assert.has_string(vim.fn.bufname(new_buf), "nvim/runtime/lua/vim/lsp.lua")

			local line = vim.fn.line('.')
			assert.is_same(line, 281)
		end)

		it("opens a split with file from stacktrace", function()
			content = h.to_table([[
  			vim.lsp.diagnostic.get_namespace(nil)
			]])
			h.set_buffer(buf, content)

			h.send_keys(config.mappings.eval)
			result = h.get_buffer(buf)

			vim.api.nvim_win_set_cursor(win, { 7, 0 })
			h.send_keys("gf")

			local new_buf = vim.fn.bufnr()
			local path = vim.fn.expand('$VIMRUNTIME') .. "/lua/vim/lsp/diagnostic.lua"
			assert.has_string(vim.fn.bufname(new_buf), path)

			local line = vim.fn.line('.')
			assert.is_same(line, 189)
		end)

		it("sets autocommand to close window on lost focus", function()
			vim.cmd("ene")

			win = vim.fn.winbufnr(buf)
			assert.are_same(win, -1)
			assert.is_false(Lua_console.win)
		end)

		it("sets autocommand to remember height on win close", function()
			result = vim.api.nvim_win_get_height(win)
			vim.cmd("ene")

			assert.are_same(result, Lua_console.height)
		end)
	end)
end)
