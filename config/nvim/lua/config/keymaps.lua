-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>ll", function()
  require("lint").try_lint()
end, { desc = "Lint current file" })

-- Default is "jj" for Escape

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit Insert Mode" })

-- Some people also like "jk" as an alternative
vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit Insert Mode" })
