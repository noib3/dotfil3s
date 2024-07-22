return {
  {
    "saecki/crates.nvim",
    opts = {
      completion = {
        cmp = {
          enabled = true
        },
        crates = {
          enabled = true,
          min_chars = 1,
        }
      },
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    }
  },
}
