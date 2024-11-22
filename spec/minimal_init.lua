local cwd = vim.fs.root(debug.getinfo(1, "S").source:sub(2), '.git')
vim.opt.rtp:append(cwd)
