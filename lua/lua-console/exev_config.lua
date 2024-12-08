---Formats the output of external evaluator
---@param result string[]
---@return string[]
local function generic_formatter(result)
  local width = vim.o.columns
  local sep_start = ('='):rep(width)
  local sep_end = ('='):rep(width)

  table.insert(result, 1, sep_start)
  table.insert(result, sep_end)

  return result
end

local external_evaluators = {
  lang_prefix = '===',
  default_process_opts = {
    cwd = nil,
    env = { EMPTY = '' },
    clear_env = false,
    stdin = false,
    stdout = false,
    stderr = false,
    text = true,
    timeout = nil,
    detach = false,
    on_exit = nil,
  },

  ruby = {
    cmd = { 'ruby', '-e' },
    env = { RUBY_VERSION = '3.3.0' },
    code_prefix = '$stdout.sync = true;',
    formatter = generic_formatter,
  },

  racket = {
    cmd = { 'racket', '-e' },
    formatter = generic_formatter,
  },

  python = {
    cmd = { 'python3', '-c' },
    formatter = generic_formatter,
  },
}

return external_evaluators
