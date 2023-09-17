local three = require("three")
local M = {}

---Get the saved data for this extension
---@return any
M.on_save = function()
  return three.save_state()
end

M.on_pre_load = function()
  require("three.bufferline.state").set_freeze(true)
end

---Restore the extension state
---@param data any The value returned from on_save
M.on_load = function(data)
  require("three.bufferline.state").set_freeze(false)
  three.restore_state(data)
end

return M
