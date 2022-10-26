local state = require("three.bufferline.state")
local M = {}

---@param group string
---@param field string
---@return nil|string
local function get_color(group, field)
  local id = vim.fn.hlID(group)
  if id == 0 then
    return nil
  end
  local color = vim.fn.synIDattr(id, field, "gui")
  return color ~= "" and color or nil
end

local function get_color_fallback(...)
  for _, pair in ipairs({ ... }) do
    local color = get_color(unpack(pair))
    if color then
      return color
    end
  end
end

local function set_colors()
  -- TabLine (standard)
  -- TabLineSel (standard)
  -- TabLineVisible
  -- TabLineFill (standard)
  -- TabLineDir
  -- TabLineScrollIndicator
  -- TabLineDivider
  -- TabLineDividerSel
  -- TabLineDividerVisible
  -- TabLineIndex
  -- TabLineIndexSel
  -- TabLineIndexVisible
  -- TabLineModified
  -- TabLineModifiedSel
  -- TabLineModifiedVisible
  -- TabLineDividerModified
  -- TabLineDividerModifiedSel
  -- TabLineDividerModifiedVisible
  -- TabLineIndexModified
  -- TabLineIndexModifiedSel
  -- TabLineIndexModifiedVisible
  vim.api.nvim_set_hl(0, "TabLineVisible", { default = true, link = "TabLine" })

  vim.api.nvim_set_hl(0, "TabLineDir", {
    default = true,
    bg = get_color("TabLineFill", "bg#"),
    fg = get_color_fallback({ "Title", "fg#" }, { "TabLineSel", "fg#" }),
  })
  vim.api.nvim_set_hl(0, "TabLineScrollIndicator", {
    default = true,
    bg = get_color("TabLineFill", "bg#"),
    fg = get_color("TabLine", "fg#"),
  })
  -- TabLineModified
  for _, status in ipairs({ "", "Sel", "Visible" }) do
    vim.api.nvim_set_hl(0, "TabLineModified" .. status, {
      default = true,
      bg = get_color_fallback({ "TabLine" .. status, "bg#" }, { "TabLine", "bg#" }),
      fg = get_color_fallback(
        { "DiagnosticWarn", "fg#" },
        { "TabLine" .. status, "fg#" },
        { "TabLine", "fg#" }
      ),
    })
  end

  for _, mod in ipairs({ "", "Modified" }) do
    for _, status in ipairs({ "", "Sel", "Visible" }) do
      -- TabLineIndex
      local index_fg
      if status ~= "" then
        index_fg = get_color_fallback(
          { "Title", "fg#" },
          { "TabLine" .. status, "fg#" },
          { "TabLine", "fg#" }
        )
      else
        index_fg = get_color_fallback({ "TabLine" .. status, "fg#" }, { "TabLine", "fg#" })
      end
      vim.api.nvim_set_hl(0, "TabLineIndex" .. mod .. status, {
        default = true,
        bg = get_color_fallback({ "TabLine" .. status, "bg#" }, { "TabLine", "bg#" }),
        fg = index_fg,
        bold = status ~= "",
      })
      -- TabLineDivider
      vim.api.nvim_set_hl(0, "TabLineDivider" .. mod .. status, {
        default = true,
        bg = get_color_fallback({ "TabLine" .. status, "bg#" }, { "TabLine", "bg#" }),
        fg = get_color_fallback({ "TabLineFill", "bg#" }, { "Normal", "bg#" }),
      })
    end
  end
end

---@private
M.setup = function(config)
  local group = vim.api.nvim_create_augroup("three.nvim", { clear = true })
  vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
    pattern = "*",
    group = group,
    callback = set_colors,
  })
  state.create_autocmds(group)
  state.display_all_buffers()
  vim.o.showtabline = 2
  vim.o.tabline = "%{%v:lua.require('three.bufferline').render()%}"
end

---@private
M.render = function()
  local renderer = require("three.bufferline.renderer")
  local ok, ret = xpcall(renderer.render, debug.traceback)
  if ok then
    return ret
  else
    vim.api.nvim_err_writeln(ret)
    return ""
  end
end

return M
