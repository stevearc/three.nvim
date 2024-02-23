local M = {}

local default_config = {
  bufferline = {
    enabled = true,
    icon = {
      -- Tab left/right dividers
      -- Set to this value for fancier, more "tab-looking" tabs
      -- dividers = { " ", "" },
      dividers = { "▍", "" },
      -- Scroll indicator icons when buffers exceed screen width
      scroll = { "«", "»" },
      -- Pinned buffer icon
      pin = "󰐃",
    },
    -- List of autocmd events that will trigger a re-render of the bufferline
    events = {},
    should_display = function(tabpage, bufnr, ts)
      return vim.bo[bufnr].buflisted or vim.bo[bufnr].modified
    end,
    -- Number of tabs to use for buffers with should_display = false
    recency_slots = 1,
  },
  windows = {
    enabled = true,
    -- Constant or function to calculate the minimum window width of the focused window
    winwidth = function(winid)
      local bufnr = vim.api.nvim_win_get_buf(winid)
      return math.max(vim.bo[bufnr].textwidth, 80)
    end,
    -- Constant or function to calculate the minimum window height of the focused window
    winheight = 10,
  },
  projects = {
    enabled = true,
    -- Name of file to store the project directory cache
    filename = "projects.json",
    -- When true, automatically add directories entered as projects
    -- If false, you will need to manually call add_project()
    autoadd = true,
    -- List of lua patterns. If any match the directory, it will be allowed as a project
    allowlist = {},
    -- List of lua patterns. If any match the directory, it will be ignored as a project
    blocklist = {},
    -- Return true to allow a directory as a project
    filter_dir = function(dir)
      return true
    end,
  },
}

M.setup = function(opts)
  local new_conf = vim.tbl_deep_extend("force", default_config, opts or {})
  for k, v in pairs(new_conf) do
    M[k] = v
  end
end

return M
