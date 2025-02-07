local colors = require('term.colors')
local inspect = require('inspect')

local log = function(...) --luacheck: ignore
  local caller = debug.getinfo(2)
  local caller_path = caller.short_src

  local time = os.date('*t', os.time())
  time.min, time.sec = 0, 0

---@diagnostic disable-next-line
  time = os.time() - os.time(time)

  if caller_path then
    local path_dirs = vim.split(vim.fs.dirname(caller_path), '/')
    caller_path = path_dirs[#path_dirs] .. '/' .. vim.fs.basename(caller_path)
  end

  local result = ('\nLOG #%s (%s:%s:%s) => '):format(
    time,
    caller_path or '',
    caller.name or '',
    caller.currentline or ''
  )

  local nargs = select('#', ...)
  local var_no = ''

  for i = 1, nargs do
    local o = select(i, ...)

    if i > 1 then result = result .. ',\n ' end
    if nargs > 1 then var_no = string.format('[%s] ', i) end

    o = type(o) == 'function' and debug.getinfo(o) or o
    result = result .. var_no .. inspect(o)
  end

  io.write(colors.cyan(result))
  io.write('\n')
  io.flush()

  return result
end

return log
