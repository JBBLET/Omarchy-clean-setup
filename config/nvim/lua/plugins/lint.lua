return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },
      linters_by_ft = {
        python = { "ruff" },
        cpp = { "cpplint" },
        c = { "cpplint" },
        markdown = { "markdownlint" },
      },
      linters = {
        cpplint = {
          args = {
            "--filter=-whitespace/labels,-whitespace/indent,-whitespace/braces",
            "--linelength=120",
          },
        },
      },
    },
  },
}
