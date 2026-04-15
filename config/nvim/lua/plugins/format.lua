return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        ["clang-format"] = {
          prepend_args = {
            -- IndentWidth: 4 for code
            -- AccessModifierOffset: -3 (4 - 3 = 1 space from the left)
            "-style={IndentWidth: 4, BasedOnStyle: Google, AccessModifierOffset: -3,ColumnLimit:120}",
          },
        },
      },
    },
  },
}
