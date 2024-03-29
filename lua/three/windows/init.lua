local root_config = require("three.config")
local M = {}

local config = setmetatable({}, {
  __index = function(_, key)
    return root_config.windows[key]
  end,
})

local enabled = true

local function set_winlayout_data(layout)
  local type = layout[1]
  if type == "leaf" then
    local winid = layout[2]
    local winfixwidth = vim.wo[winid].winfixwidth
    local winfixheight = vim.wo[winid].winfixheight
    local min_width = winfixwidth and vim.api.nvim_win_get_width(winid) or 0
    local min_height = winfixheight and vim.api.nvim_win_get_height(winid) or 0
    if vim.api.nvim_get_current_win() == winid then
      if not winfixwidth then
        min_width = config.winwidth(winid)
      end
      if not winfixheight then
        min_height = config.winheight
      end
    end
    layout[2] = {
      winid = winid,
      min_width = min_width,
      min_height = min_height,
      winfixwidth = winfixwidth,
      winfixheight = winfixheight,
      width = min_width,
      height = min_height,
    }
  else
    local winfixwidth = false
    local winfixheight = false
    local min_width = 0
    local min_height = 0
    local width = 0
    local height = 0
    for _, v in ipairs(layout[2]) do
      set_winlayout_data(v)
      winfixwidth = winfixwidth or v[2].winfixwidth
      winfixheight = winfixheight or v[2].winfixheight
      if type == "row" then
        min_width = min_width + v[2].min_width
        min_height = math.max(min_height, v[2].min_height)
        width = width + v[2].width
        height = math.max(height, v[2].height)
      else
        min_width = math.max(min_width, v[2].min_width)
        min_height = min_height + v[2].min_height
        width = math.max(width, v[2].width)
        height = height + v[2].height
      end
    end
    layout[2].winfixwidth = winfixwidth
    layout[2].winfixheight = winfixheight
    layout[2].min_width = min_width
    layout[2].min_height = min_height
    layout[2].width = width
    layout[2].height = height
  end
end

local function balance(sections, extra, key)
  if vim.tbl_isempty(sections) then
    return
  end
  local min_val
  local second_min
  local min_count = 0
  for _, v in ipairs(sections) do
    local dim = v[2][key]
    if not min_val or dim < min_val then
      second_min = min_val
      min_val = dim
      min_count = 1
    elseif dim == min_val then
      min_count = min_count + 1
    elseif not second_min or dim < second_min then
      second_min = dim
    end
  end
  local total_boost = extra
  if second_min then
    total_boost = math.min(extra, second_min - min_val)
  end
  local boost = math.floor(total_boost / min_count)
  local mod = total_boost % min_count
  for _, v in ipairs(sections) do
    if v[2][key] == min_val then
      v[2][key] = v[2][key] + boost
      extra = extra - boost
      if mod > 0 then
        mod = mod - 1
        v[2][key] = v[2][key] + 1
        extra = extra - 1
      end
    end
  end
  if extra > 0 then
    balance(sections, extra, key)
  end
end

local function set_dimensions(layout)
  local type = layout[1]
  if type == "leaf" then
    local info = layout[2]
    if vim.api.nvim_win_is_valid(info.winid) then
      local view
      vim.api.nvim_win_call(info.winid, function()
        view = vim.fn.winsaveview()
      end)
      pcall(vim.api.nvim_win_set_width, info.winid, info.width)
      pcall(vim.api.nvim_win_set_height, info.winid, info.height)
      vim.api.nvim_win_call(info.winid, function()
        vim.fn.winrestview(view)
      end)
    end
  else
    local sections = layout[2]
    if type == "row" then
      -- Adjust the width for the split borders
      sections.width = sections.width - (#sections - 1)
      local flex = {}
      for _, v in ipairs(sections) do
        if not v[2].winfixwidth then
          table.insert(flex, v)
        end
      end
      local remainder = sections.width - sections.min_width
      balance(flex, remainder, "width")
      for _, v in ipairs(sections) do
        v[2].height = sections.height
        set_dimensions(v)
      end
    else
      -- Adjust the height for the split borders
      sections.height = sections.height - (#sections - 1)
      local flex = {}
      for _, v in ipairs(sections) do
        if not v[2].winfixheight then
          table.insert(flex, v)
        end
      end
      local remainder = sections.height - sections.min_height
      balance(flex, remainder, "height")
      for _, v in ipairs(sections) do
        v[2].width = sections.width
        set_dimensions(v)
      end
    end
  end
end

local function resize_windows()
  if not enabled then
    return
  end
  local layout = vim.fn.winlayout()
  set_winlayout_data(layout)
  layout[2].width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight
  if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) then
    editor_height = editor_height - 1
  end
  if
    vim.o.laststatus >= 2 or (vim.o.laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
  then
    editor_height = editor_height - 1
  end
  layout[2].height = editor_height
  set_dimensions(layout)
end

---@return boolean
M.toggle_win_resize = function()
  enabled = not enabled
  return enabled
end

---@param new_enabled boolean
M.set_win_resize = function(new_enabled)
  enabled = new_enabled
end

---@private
M.setup = function()
  vim.o.winwidth = 1
  vim.o.winheight = 1
  vim.o.splitbelow = true
  vim.o.splitright = true

  local group = vim.api.nvim_create_augroup("three.windows", {})

  vim.api.nvim_create_autocmd({ "VimEnter", "WinEnter", "BufWinEnter", "VimResized" }, {
    desc = "Keep all windows equal size",
    pattern = "*",
    -- Delay in case we're switching to a window and then switching back immediately.
    -- Happens when opening the LSP hover floating window, for example.
    callback = vim.schedule_wrap(resize_windows),
    group = group,
  })
end

return M
