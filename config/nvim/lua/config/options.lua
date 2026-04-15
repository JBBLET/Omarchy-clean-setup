-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.mouse = ""
-- Global indentation settings
vim.opt.shiftwidth = 4 -- Size of an indent
vim.opt.tabstop = 4 -- Number of spaces tabs count for
vim.opt.expandtab = true -- Use spaces instead of tabs

-- This tells Neovim to ignore what the LSP thinks the indent should be
vim.g.autoformat = true

vim.opt.colorcolumn = "120"
