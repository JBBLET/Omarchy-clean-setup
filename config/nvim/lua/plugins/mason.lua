---@diagnostic disable: undefined-global
return {
  {
    "mason-org/mason.nvim", -- LazyVim handles the rename internally, but you can keep this name
    opts = {
      ensure_installed = {
        "ruff",
        "cpplint",
        "markdownlint",
        "clang-format",
        "clangd",
        "pyright",
      },
    },
  },
}
