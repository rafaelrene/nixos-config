-- The selected workstation theme supplies the plugin and its options.
local theme = vim.json.decode(table.concat(vim.fn.readfile("/etc/xdg/nvim-theme.json"), "\n"))

return {
  {
    theme.plugin,
    lazy = true,
    name = theme.name,
    opts = theme.opts,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = theme.colorscheme },
  },
}
