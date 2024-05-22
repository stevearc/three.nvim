local root_config = require("three.config")
local util = require("three.util")
local config = setmetatable({}, {
  __index = function(_, key)
    return root_config.bufferline[key]
  end,
})

local M = {}

---@class three.TabState
---@field buffers integer[]
---@field buf_info table<integer, three.BufferState>

---@class three.BufferState
---@field bufnr integer
---@field pinned? boolean

local tabstate_meta = {
  __newindex = function(t, key, val)
    if key == 0 then
      t[vim.api.nvim_get_current_tabpage()] = val
    else
      rawset(t, key, val)
    end
  end,
  __index = function(t, key)
    if key == 0 then
      return t[vim.api.nvim_get_current_tabpage()]
    else
      local ts = {
        buffers = {},
        buf_info = {},
      }
      t[key] = ts
      return ts
    end
  end,
}

---@type table<integer, three.TabState>
local tabstate = setmetatable({}, tabstate_meta)
local frozen = false

---Get the saved state of the bufferline
---@return any
M.save_state = function()
  local ret = {}
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local ts = tabstate[tabpage]
    local serialized = {
      buffers = {},
    }
    table.insert(ret, serialized)
    for _, bufnr in ipairs(ts.buffers) do
      local buf_info = ts.buf_info[bufnr]
      table.insert(serialized.buffers, {
        name = vim.api.nvim_buf_get_name(bufnr),
        pinned = buf_info.pinned,
      })
    end
  end
  return ret
end

---Restore the previously saved state
---@param state any
M.restore_state = function(state)
  tabstate = {}
  for i, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    local ts = state[i]
    if ts then
      local new_ts = {
        buffers = {},
        buf_info = {},
      }
      tabstate[tabpage] = new_ts
      for _, buf_info in ipairs(ts.buffers) do
        local bufnr = vim.fn.bufadd(buf_info.name)
        table.insert(new_ts.buffers, bufnr)
        new_ts.buf_info[bufnr] = {
          bufnr = bufnr,
          pinned = buf_info.pinned,
        }
      end
    end
  end
  setmetatable(tabstate, tabstate_meta)
end

---@param ts three.TabState
local function sort_pins_to_left(ts)
  local pinned = {}
  local unpinned = {}
  for _, bufnr in ipairs(ts.buffers) do
    if ts.buf_info[bufnr].pinned then
      table.insert(pinned, bufnr)
    else
      table.insert(unpinned, bufnr)
    end
  end
  ts.buffers = vim.list_extend(pinned, unpinned)
end

local function apply_sorting()
  local ts = tabstate[0]
  sort_pins_to_left(ts)
end

---@param tabpage integer
---@return table<integer, boolean>
local function get_visible_buffers(tabpage)
  local visible = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if vim.api.nvim_win_is_valid(winid) then
      visible[vim.api.nvim_win_get_buf(winid)] = true
    end
  end
  return visible
end

---@param tabpage integer
---@param bufnr integer
---@param visible? table<integer, boolean>
---@return boolean
local function should_display(tabpage, bufnr, visible)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local ts = tabstate[tabpage]
  if
    #ts.buffers == 0
    and vim.api.nvim_buf_get_name(bufnr) == ""
    and vim.api.nvim_buf_line_count(bufnr) == 1
  then
    -- don't display single empty buffers
    return false
  elseif ts.buf_info[bufnr] and ts.buf_info[bufnr].pinned then
    return true
  elseif not vim.bo[bufnr].buflisted then
    return false
  end

  if not visible then
    visible = get_visible_buffers(tabpage)
  end
  return visible[bufnr] or config.should_display(tabpage, bufnr, ts)
end

---@param tabpage integer
---@param bufnr integer
---@param sort nil|boolean
---@return boolean
local function add_buffer(tabpage, bufnr, sort)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local ts = tabstate[tabpage]
  if ts.buf_info[bufnr] then
    return false
  end
  table.insert(ts.buffers, bufnr)
  ts.buf_info[bufnr] = {
    bufnr = bufnr,
  }
  if sort or sort == nil then
    apply_sorting()
  end
  return true
end

---Check if buffer is listed in any tab
---@param bufnr integer
---@return boolean
M.is_buffer_in_any_tab = function(bufnr)
  for _, ts in pairs(tabstate) do
    if ts.buf_info[bufnr] then
      return true
    end
  end
  return false
end

---@class (exact) three.bufferSelectOpts
---@field delta nil|integer Offset from current buffer
---@field wrap nil|boolean If true, wrap around the buffer list

---@param bufnr integer
---@param opts? three.bufferSelectOpts
---@return nil|integer
M.get_relative_buffer = function(bufnr, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    delta = 1,
    wrap = false,
  })
  local ts = tabstate[0]
  if vim.tbl_isempty(ts.buffers) then
    return nil
  end
  local idx = util.tbl_index(ts.buffers, bufnr)
  if idx then
    idx = idx + opts.delta
    if opts.wrap then
      idx = (idx - 1) % #ts.buffers + 1
    else
      idx = math.max(1, math.min(#ts.buffers, idx))
    end
  else
    idx = 1
  end
  return ts.buffers[idx]
end

---@param opts? three.bufferSelectOpts
M.next = function(opts)
  local curbuf = vim.api.nvim_get_current_buf()
  local newbuf = M.get_relative_buffer(curbuf, opts)
  if newbuf then
    vim.api.nvim_win_set_buf(0, newbuf)
    util.rerender()
  end
end

---@param opts? three.bufferSelectOpts
M.prev = function(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    delta = 1,
    wrap = false,
  })
  opts.delta = -1 * opts.delta
  local curbuf = vim.api.nvim_get_current_buf()
  local newbuf = M.get_relative_buffer(curbuf, opts)
  if newbuf then
    vim.api.nvim_win_set_buf(0, newbuf)
    util.rerender()
  end
end

---@param position integer
M.move_buffer = function(position)
  local ts = tabstate[0]
  local bufnr = vim.api.nvim_get_current_buf()
  local idx = util.tbl_index(ts.buffers, bufnr)
  if idx then
    position = math.max(1, math.min(#ts.buffers, position))
    table.remove(ts.buffers, idx)
    table.insert(ts.buffers, position, bufnr)
    apply_sorting()
    util.rerender()
  end
end

---@param opts? three.bufferSelectOpts
M.move_buffer_relative = function(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    delta = 1,
    wrap = false,
  })
  local ts = tabstate[0]
  local bufnr = vim.api.nvim_get_current_buf()
  local idx = util.tbl_index(ts.buffers, bufnr)
  if idx then
    idx = idx + opts.delta
    if opts.wrap then
      idx = (idx - 1) % #ts.buffers + 1
    else
      idx = math.max(1, math.min(#ts.buffers, idx))
    end
    M.move_buffer(idx)
  end
end

---@param opts? three.bufferSelectOpts
M.move_right = function(opts)
  M.move_buffer_relative(opts)
end

---@param opts? three.bufferSelectOpts
M.move_left = function(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    delta = 1,
    wrap = false,
  })
  opts.delta = -1 * opts.delta
  M.move_buffer_relative(opts)
end

---@param opts? three.bufferSelectOpts
local function get_relative_tab(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    delta = 1,
    wrap = false,
  })
  local curtab = vim.api.nvim_get_current_tabpage()
  local tabpages = vim.api.nvim_list_tabpages()
  local idx = util.tbl_index(tabpages, curtab)
  if idx then
    idx = idx + opts.delta
    if opts.wrap then
      idx = (idx - 1) % #tabpages + 1
    else
      idx = math.max(1, math.min(#tabpages, idx))
    end
  else
    idx = 1
  end
  return tabpages[idx]
end

---@param opts? three.bufferSelectOpts
M.next_tab = function(opts)
  local tabpage = get_relative_tab(opts)
  vim.api.nvim_set_current_tabpage(tabpage)
end

---@param opts? three.bufferSelectOpts
M.prev_tab = function(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    delta = 1,
    wrap = false,
  })
  opts.delta = -1 * opts.delta
  local tabpage = get_relative_tab(opts)
  vim.api.nvim_set_current_tabpage(tabpage)
end

---@param idx integer
M.jump_to = function(idx)
  local ts = tabstate[0]
  local buf = ts.buffers[idx]
  if buf then
    vim.api.nvim_win_set_buf(0, buf)
    util.rerender()
  else
    vim.notify(string.format("No buffer at index %s", idx), vim.log.levels.WARN)
  end
end

---@param tabpage integer
---@param bufnr integer
---@return boolean
local function remove_buffer_from_tabstate(tabpage, bufnr)
  local ts = tabstate[tabpage]
  local idx = util.tbl_index(ts.buffers, bufnr)
  if idx then
    table.remove(ts.buffers, idx)
    ts.buf_info[bufnr] = nil
    return true
  else
    return false
  end
end

---@param bufnr integer
---@return boolean
local function remove_buffer_from_tabstates(bufnr)
  local any_changes = false
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    any_changes = remove_buffer_from_tabstate(tabpage, bufnr) or any_changes
  end
  return any_changes
end

---@param bufnr integer
local function touch_buffer(bufnr)
  if should_display(0, bufnr) then
    if add_buffer(0, bufnr) then
      util.rerender()
    end
  else
    local ts = tabstate[0]
    if
      ts.buf_info[bufnr]
      and not ts.buf_info[bufnr].pinned
      -- only remove the buffer if it's not pinned
      and remove_buffer_from_tabstates(bufnr)
    then
      util.rerender()
    end
  end
end

---@param tabpage integer
---@param bufnr integer
---@return nil|integer
local function get_fallback_buffer(tabpage, bufnr)
  local replacement = M.get_relative_buffer(bufnr, { delta = -1 })
  if not replacement or replacement == bufnr then
    replacement = M.get_relative_buffer(bufnr, { delta = 1 })
  end

  if replacement == bufnr then
    replacement = nil
  end
  if replacement == nil then
    replacement = vim.api.nvim_create_buf(false, true)
    vim.bo[replacement].bufhidden = "wipe"
  end
  return replacement
end

---@param tabpage integer
---@param bufnr integer
local function remove_buf_from_tab_wins(tabpage, bufnr)
  local ts = tabstate[tabpage]
  if vim.tbl_contains(ts.buffers, bufnr) then
    local fallback = get_fallback_buffer(tabpage, bufnr)
    if fallback then
      for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_is_valid(winid) then
          if vim.api.nvim_win_get_buf(winid) == bufnr then
            vim.api.nvim_win_set_buf(winid, fallback)
          end
        end
      end
    end
  end
end

---@param bufnr nil|integer
---@param force nil|boolean
M.close_buffer = function(bufnr, force)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    remove_buf_from_tab_wins(tabpage, bufnr)
    remove_buffer_from_tabstate(tabpage, bufnr)
  end

  vim.cmd.bwipeout({ args = { bufnr }, mods = { bang = force } })
end

---Toggle the pinned status of the current buffer
M.toggle_pin = function()
  local ts = tabstate[0]
  local bufnr = vim.api.nvim_get_current_buf()
  local pinned = false
  if ts.buf_info[bufnr] then
    pinned = ts.buf_info[bufnr].pinned
  end
  M.set_pinned({ bufnr }, not pinned)
end

---Set the pinned status of a buffer or buffers
---@param bufnrs integer|integer[]
---@param pinned boolean
M.set_pinned = function(bufnrs, pinned)
  local ts = tabstate[0]
  if type(bufnrs) ~= "table" then
    bufnrs = { bufnrs }
  end
  for _, bufnr in ipairs(bufnrs) do
    if ts.buf_info[bufnr] then
      ts.buf_info[bufnr].pinned = pinned
      if not pinned and not should_display(0, bufnr) then
        remove_buffer_from_tabstate(0, bufnr)
      end
    elseif pinned then
      -- We're pinning a buffer we haven't added to the display yet
      add_buffer(0, bufnr, false)
      ts.buf_info[bufnr].pinned = pinned
    end
  end
  apply_sorting()
  util.rerender()
end

---Clone the current tab into a new tab
M.clone_tab = function()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local ts = tabstate[tabpage]
  local bufnr = vim.api.nvim_get_current_buf()
  vim.cmd.tabnew()
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"
  tabstate[0] = vim.deepcopy(ts)
  vim.api.nvim_set_current_buf(bufnr)
end

local function other_normal_window_exists()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local curwin = vim.api.nvim_get_current_win()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if util.is_normal_win(winid) and curwin ~= winid then
      return true
    end
  end
  return false
end

---Close the current window or buffer
M.smart_close = function()
  local curwin = vim.api.nvim_get_current_win()
  -- if we're in a non-normal or floating window: close
  if not util.is_normal_win(0) then
    vim.cmd.close()
    return
  end

  -- You can tag a window for smart_close to always close the buffer by setting the window
  -- variable vim.w.smart_close_buffer = true
  local close_buffer = vim.w[curwin].smart_close_buffer
  if close_buffer then
    local bufnr = vim.api.nvim_get_current_buf()
    if other_normal_window_exists() then
      vim.cmd.close()
    elseif #vim.api.nvim_list_tabpages() > 1 then
      vim.cmd.tabclose()
    end
    M.close_buffer(bufnr)
  elseif other_normal_window_exists() then
    vim.cmd.close()
  else
    M.close_buffer()
  end
end

---Hide the buffer from the current tab
---@param bufnr nil|integer
M.hide_buffer = function(bufnr)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  remove_buf_from_tab_wins(0, bufnr)
  remove_buffer_from_tabstate(0, bufnr)
end

local function cull_visible_buffers()
  if frozen then
    return
  end
  local ts = tabstate[0]
  local to_remove = {}
  local num_remove = 0
  local visible = get_visible_buffers(0)
  for _, bufnr in ipairs(ts.buffers) do
    if not should_display(0, bufnr, visible) then
      num_remove = num_remove + 1
      if num_remove > config.recency_slots then
        table.insert(to_remove, bufnr)
      end
    end
  end
  for _, bufnr in ipairs(to_remove) do
    remove_buffer_from_tabstate(0, bufnr)
  end
  if not vim.tbl_isempty(to_remove) then
    util.rerender()
  end
end

---@private
M.create_autocmds = function(group)
  vim.api.nvim_create_autocmd({ "BufNew", "TermOpen", "BufEnter" }, {
    pattern = "*",
    group = group,
    callback = function(params)
      if not frozen then
        touch_buffer(params.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd(config.events, {
    pattern = "*",
    group = group,
    callback = vim.schedule_wrap(function(params)
      cull_visible_buffers()
    end),
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "buflisted",
    group = group,
    callback = function(params)
      local bufnr = params.buf
      if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
      end
      if not frozen then
        touch_buffer(bufnr)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    pattern = "*",
    group = group,
    -- Delay this so that we don't remove the buffer if it's getting reloaded
    callback = vim.schedule_wrap(function(params)
      if vim.api.nvim_buf_is_loaded(params.buf) then
        return
      end
      if not frozen and remove_buffer_from_tabstates(params.buf) then
        util.rerender()
      end
    end),
  })
end

---@private
M.display_all_buffers = function()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if should_display(0, bufnr) then
      add_buffer(0, bufnr)
    end
  end
end

---@private
---@param freeze boolean
M.set_freeze = function(freeze)
  frozen = freeze
end

---@param tabpage integer
---@return three.TabState
M.get_tab_state = function(tabpage)
  return tabstate[tabpage]
end

return M
