local M = {}

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

M = {
  get_locals = get_locals
}

return M
