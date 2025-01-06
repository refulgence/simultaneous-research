---@class Utils
local utils = {}

---Converts a table of ingredients to a set
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

---Sorts current_research_data by the "sort_index" field
function utils.sort_by_index()
    local data = storage.current_research_data
    local keys = {}
    for key, _ in pairs(data) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return data[a].sort_index < data[b].sort_index
    end)
    local sorted_table = {}
    for _, key in ipairs(keys) do
        sorted_table[key] = data[key]
    end
    storage.current_research_data = sorted_table
end

return utils