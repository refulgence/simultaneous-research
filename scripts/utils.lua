---@class Utils
local utils = {}

---Converts a table to a set
---@param input table
---@return table
function utils.normalize_to_set(input)
    local result = {}
    for k, v in pairs(input) do
        if type(k) == "number" and v ~= nil then
            result[v.name] = true
        else
            result[k] = v
        end
    end
    return result
end

return utils