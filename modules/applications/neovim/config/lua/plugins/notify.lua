local theme = vim.json.decode(table.concat(vim.fn.readfile("/etc/xdg/nvim-theme.json"), "\n"))

return {
  "rcarriga/nvim-notify",
  opts = {
    background_colour = theme.background,
  },
}
