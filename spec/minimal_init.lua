local cwd = vim.fs.root(debug.getinfo(1, "S").source, '.git')
vim.opt.rtp:append(cwd)
package.path = cwd .. '/spec/?.lua;' .. package.path
