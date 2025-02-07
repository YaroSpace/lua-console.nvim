local assert = require('luassert.assert')
local match = require('luassert.match')

_G.LOG = require('log')

local M = {}

--Remove tabs and spaces as tabs
string.clean = function(str) --luacheck: ignore
  return vim.trim(str:gsub('\t', '')) -- gsub('%s%s+', '')
end

M.get_root = function()
  local path = debug.getinfo(1, 'S').source:sub(2)
  return vim.fs.root(path, '.git')
end

---@param tbl string[]|string
M.to_string = function(tbl)
  tbl = tbl or {}

  if type(tbl) ~= 'table' then tbl = { tbl } end
  return table.concat(tbl, '\n'):clean()
end

M.to_table = function(str)
  return vim.split(str:clean() or '', '\n', { trimempty = true })
end

M.delete_buffer = function(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

M.get_buffer = function(buf)
  ---@diagnostic disable-next-line
  return vim.fn.getbufline(buf, 0, '$')
end

---@param lines string[]
M.set_buffer = function(buf, lines)
  return vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

---@param buf? number|nil -- get global maps if nil
---@param mode? string -- default 'n'
M.get_maps = function(buf, mode)
  mode = mode or 'n'
  local maps = {}
  local list = buf and vim.api.nvim_buf_get_keymap(buf, mode) or vim.api.nvim_get_keymap(mode)

  vim.tbl_map(function(map)
    maps[map.lhs] = map.desc
  end, list)

  return maps
end

M.send_keys = function(keys)
  local cmd = "'normal " .. keys .. "'"
  vim.cmd.exe(cmd)
end

M.get_virtual_text = function(buf, line_start, line_end)
  local ids = vim.api.nvim_buf_get_extmarks(buf, -1, { line_start or 0, 0 }, { line_end or -1, -1 }, { details = true })

  if vim.tbl_isempty(ids) then
    _G.LOG('No extmarks found')
    return ''
  end

  local marks = vim.tbl_map(function(mark)
    return mark[4].virt_text[1][1]
  end, ids)

  return marks
end

---Collects paths for nested keys
local get_key_paths
get_key_paths = function(tbl, path, paths)
  path = path or {}
  paths = paths or {}

  if type(tbl) ~= 'table' then return end

  for k, v in pairs(tbl) do
    local nested_path = vim.list_extend({ path }, { k })

    if not get_key_paths(v, nested_path, paths) then table.insert(paths, vim.fn.flatten(nested_path)) end
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

local function compare_strings(str_1, str_2)
  local char_1, char_2, pos
  for i = 1, #str_1 do
    pos, char_1, char_2 = i, str_1:sub(i, i), str_2:sub(i, i)
    if char_1 ~= char_2 then break end
  end

  if not pos then return '' end
  pos = pos + 1

  local sub_1 = str_1:sub(pos - 5, pos - 1) .. '<< ' .. str_1:sub(pos, pos) .. ' >>' .. str_1:sub(pos + 1, pos + 5)
  local sub_2 = str_2:sub(pos - 5, pos - 1) .. '<< ' .. str_2:sub(pos, pos) .. ' >>' .. str_2:sub(pos + 1, pos + 5)

  return ('Mismatch in pos %s\n%s\n\n%s'):format(pos, sub_1, sub_2)
end

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

  o = o:clean()
  pattern = pattern:clean()

  result = o:find(pattern, 1, true) and true or false

  if not (mod and result) then
    local _not = mod and '' or ' not '
    local mismatch = compare_strings(o, pattern)
    state.failure_message =
      string.format('\n\n**Expected "%s"\n\n**%sto have string "%s\n\n%s"', o, _not, pattern, mismatch)
  end

  return result
end

assert:register('assertion', 'has_string', M.has_string, '', '')

return M
