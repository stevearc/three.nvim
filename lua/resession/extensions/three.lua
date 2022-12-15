local three = require("three")
local M = {}

---@param data table The configuration data passed in the config
M.config = function(data)
  require("resession").add_hook("pre_load", function()
    require("three.bufferline.state").set_freeze(true)
  end)
end

---Get the saved data for this extension
---@return any
M.on_save = function()
  return three.save_state()
end

---Restore the extension state
---@param data any The value returned from on_save
M.on_load = function(data)
  require("three.bufferline.state").set_freeze(false)
  three.restore_state(data)
end

return M
