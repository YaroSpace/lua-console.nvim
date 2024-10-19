local config = require('lua-console.config')

---Loads saved console
local load_console = function()
  if vim.fn.filereadable(config.buffer.save_path) == 0 then return end

  local file = vim.fn.readfile(config.buffer.save_path)
  vim.api.nvim_buf_set_lines(Lua_console.buf, 0, -1, false, file)
end

---@param text string Text to append to buffer
local append_current_buffer = function(text)
  local line = math.max(vim.fn.line('.'), vim.fn.line('v'))
  vim.api.nvim_buf_set_lines(0, line, line, false, vim.split('\n' .. config.buffer.prepend_result_with .. text, "\n"))
end

---Appends pretty printed text to current buffer
---@param object any Lua object
local pretty_print = function(object)
  append_current_buffer(vim.inspect(object))
end

---Evaluates Lua code and returns pretty printed result with errors if any
---@param chunk string String with Lua code
local eval_lua = function(chunk)
  if select(2, chunk:gsub("\n", "")) < 1 then
    chunk = "return " .. chunk
  end

  local env = setmetatable({ print = pretty_print }, { __index = _G })

  local code, error = load(chunk, 'Lua console eval', "t", env)
  if error then return error end

  local status, result = xpcall(code, debug.traceback)
  if not status then return result end

  result = type(result) == 'function' and debug.getinfo(result) or result
  return vim.inspect(result)
end

---Evaluates lua in the current line or visual selections and appends to current buffer
local eval_lua_in_buffer = function()
  local buf  = vim.fn.bufnr()

  if vim.api.nvim_get_mode().mode == "V" then
    vim.api.nvim_input("<Esc>")
  end

  local v_start, v_end = vim.fn.line('.'), vim.fn.line('v')
  if v_start > v_end then
    v_start, v_end = v_end, v_start
  end

  local chunk = vim.api.nvim_buf_get_lines(buf, v_start - 1, v_end, false)
  chunk = table.concat(chunk, "\n")

  append_current_buffer(eval_lua(chunk))
end

local get_plugin_path = function()
  local path = debug.getinfo(1, 'S').source
  local _, pos = path:find('lua%-console.nvim')

  return path:sub(2,pos)
end

---@return table<string, any> locals Table of local variables and their values
local get_locals = function()
  local i, locals = 1, {}
  while true do
    local name, value = debug.getlocal(2, i)

    if name then locals[name] = value
    else break end

    i = i +1
  end

  return locals
end

return {
  load_console = load_console,
  append_current_buffer = append_current_buffer,
  eval_lua = eval_lua,
  eval_lua_in_buffer = eval_lua_in_buffer,
  get_locals = get_locals,
  get_plugin_path = get_plugin_path

}
