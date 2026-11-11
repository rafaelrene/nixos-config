local function has_markdownlint_config(filename)
  if not filename or filename == "" then
    return false
  end

  return vim.fs.find({
    ".markdownlint-cli2.jsonc",
    ".markdownlint-cli2.yaml",
    ".markdownlint-cli2.cjs",
    ".markdownlint-cli2.mjs",
    ".markdownlint.jsonc",
    ".markdownlint.json",
    ".markdownlint.yaml",
    ".markdownlint.yml",
    ".markdownlint.cjs",
    ".markdownlint.mjs",
  }, { path = vim.fs.dirname(filename), upward = true, type = "file" })[1] ~= nil
end

return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          condition = function(ctx)
            return has_markdownlint_config(ctx.filename)
          end,
        },
      },
    },
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      for i, source in ipairs(opts.sources or {}) do
        if source.name == "markdownlint-cli2" then
          opts.sources[i] = source.with({
            runtime_condition = function(params)
              return has_markdownlint_config(params.bufname)
            end,
          })
        end
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      local formatter = opts.formatters["markdownlint-cli2"] or {}
      local condition = formatter.condition

      formatter.condition = function(self, ctx)
        return has_markdownlint_config(ctx.filename) and (not condition or condition(self, ctx))
      end
      opts.formatters["markdownlint-cli2"] = formatter
    end,
  },
}
