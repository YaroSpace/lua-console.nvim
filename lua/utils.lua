local config = require('config')

local append_current_buffer = function(text)
  local line = math.max(vim.fn.line('.'), vim.fn.line('v'))
  vim.api.nvim_buf_set_lines(0, line, line, false, vim.split(config.buffer.prepend_result_with .. text, "\n"))
end

local pretty_print = function(text)
  append_current_buffer(vim.inspect(text))
end

local eval_lua = function(chunk)
  if select(2, chunk:gsub("\n", "")) < 1 then
    chunk = "return " .. chunk
  end

  local env = setmetatable({ print = pretty_print }, { __index = _G })

  local code, error = load(chunk, config.buffer.name, "t", env)
  if error then return error end

  local status, result = xpcall(code, debug.traceback)
  if not status then return result end

  result = type(result) == 'function' and debug.getinfo(result) or result
  return vim.inspect(result)
end

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

return {
  append_current_buffer = append_current_buffer,
  eval_lua_in_buffer = eval_lua_in_buffer,
}
