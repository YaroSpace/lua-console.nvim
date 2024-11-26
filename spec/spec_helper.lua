local assert = require("luassert.assert")
local match = require("luassert.match")

_G.LOG = require('log')

local M = {}

--Remove tabs and spaces as tabs
string.clean = function(str)
  return vim.trim(str:gsub('\t', '')) --:gsub('%s%s+', '')
end

M.get_root = function()
  local path = debug.getinfo(1, "S").source:sub(2)
  return vim.fs.root(path, '.git')
end

---@param tbl string[]|string
M.to_string = function(tbl)
  tbl = tbl or {}

  if type(tbl) == 'string' then
    tbl = { tbl }
  end
  return table.concat(tbl, '\n'):clean()
end

M.to_table = function(str)
  return vim.split(str:clean() or '', '\n', { trimempty = true })
end

M.get_buffer = function(buf)
  ---@diagnostic disable-next-line
  return vim.fn.getbufline(buf, 0, '$')
end

---@param lines string[]
M.set_buffer = function(buf, lines)
  return vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

M.send_keys = function(keys)
  local cmd = "'normal " .. keys .. "'"
  vim.cmd.exe(cmd)
end

M.get_virtual_text = function(buf, line_start, line_end)
  local ns = vim.api.nvim_create_namespace('Lua-console')
  local ids = vim.api.nvim_buf_get_extmarks(buf, ns, { line_start or 0, 0 }, { line_end or 0, -1 }, {})

  if vim.tbl_isempty(ids) then
  	_G.LOG('No extmarks found')
  	return ''
  end

  local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, ids[1][1], { details = true })

  return mark[3].virt_text[1][1]
end

---Collects paths for nested keys
local get_key_paths
get_key_paths = function(tbl, path, paths)
  path = path or {}
  paths = paths or {}

  if type(tbl) ~= 'table' then
    return
  end

  for k, v in pairs(tbl) do
    local nested_path = vim.list_extend({ path }, { k })

    if not get_key_paths(v, nested_path, paths) then
      table.insert(paths, vim.fn.flatten(nested_path))
    end
  end
  return paths
end

---Checks if an object contains properties with values
---@param state table
---@param args table { table, table { property_name = value } }
M.has_properties = function(state, args)
  vim.validate {
    arg_1 = { args[1], 'table' },
    arg_2 = { args[2], 'table' },
  }

  local mod = state.mod
  local o, properties = args[1], args[2]
  local missing = {}
  local result = true

  local key_paths = get_key_paths(properties) or {}

  for _, path in ipairs(key_paths) do
    local prop_value = vim.tbl_get(properties, unpack(path))
    if vim.tbl_get(o, unpack(path)) ~= prop_value then
      result = false
      missing[path] = prop_value
    end
  end

  if not (mod and result) then
    local _not = mod and '' or ' not '
    state.failure_message =
      string.format('\n\n**Expected "%s"\n\n**%sto have properties "%s"', vim.inspect(o), _not, vim.inspect(missing))
  end

  return result
end

assert:register('assertion', 'has_properties', M.has_properties, '', '')

---Asserts provided callback
---@param state table
---@param arguments table { [1] = function(value): boolean }
---@return function: boolean
local function assert_arg(_, arguments)
  local assert_cb = arguments[1]

  return function(value)
    assert_cb(value)
    return true
  end
end

  --weird workaround for bug in luassert.formatters.init.lua:220
  --for blank matchers match._
local function assert_arg_formatter(arg)
  if not match.is_matcher(arg) then return end
  if not arg.arguments then return '(_)' end
end

assert:register('matcher', 'assert_arg', assert_arg)
assert:add_formatter(assert_arg_formatter)

---Asserts if object contains a string
---@param state table
---@param args table { table|string, string }
---@return boolean
M.has_string = function(state, args)
  vim.validate {
    arg_1 = { args[1], { 'string', 'table' } },
    arg_2 = { args[2], { 'string', 'table' } },
  }

  local mod = state.mod
  local o, pattern = args[1], args[2]
  local result

  if type(o) == 'table' then o = M.to_string(o) end
  if type(pattern) == 'table' then pattern = M.to_string(pattern) end

  o = vim.trim(o:clean())
  pattern = vim.trim(pattern:clean())

  result = o:find(pattern, 1, true) and true or false

  if not (mod and result) then
    local _not = mod and '' or ' not '
    state.failure_message = string.format('\n\n**Expected "%s"\n\n**%sto have string "%s"', o, _not, pattern)
  end

  return result
end

assert:register('assertion', 'has_string', M.has_string, '', '')

return M
