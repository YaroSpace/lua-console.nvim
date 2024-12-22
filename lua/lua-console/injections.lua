local M = {}

---Allow syntax highlighting for languages embedded in Lua comments
M.set_highlighting = function()
  local config = require('lua-console.config')
  local lang_prefix = config.external_evaluators.lang_prefix
  local lang_pattern = ('^%s([^\\n]-)\\n.+$'):format(lang_prefix)

  vim.treesitter.query.add_directive('deindent!', function(_, _, _, predicate, metadata) -- remove indentaion in the region
    local capture_id = predicate[2]
    if not metadata[capture_id].range then return end

    metadata[capture_id].range[2] = tonumber(predicate[3]) -- set indent col to 0
  end, { all = true, force = true })

  local function extend_query(query)
    local extended = ''
    vim.tbl_map(function(path)
      extended = extended .. io.open(path):read("*a") .. '\n'
    end, vim.treesitter.query.get_files('lua', 'injections'))

    return extended .. query
  end

  local query = ([[ ;query
    ((string_content) @injection.language @injection.content
    (#lua-match? @injection.language "^@1")
    (#gsub! @injection.language "@2" "%1")
    (#offset! @injection.content 1 0 0 0)
    (#deindent! @injection.content 0))
  ]]):gsub('@1', lang_prefix):gsub('@2', lang_pattern)

  query = extend_query(query)
  vim.treesitter.query.set('lua', 'injections', query)
end

return M
