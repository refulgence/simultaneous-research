local tracking = require("scripts/tracking_utils")

for _, lab_data in pairs(storage.labs) do
    local entity = lab_data.entity
    lab_data.pollution = 1
    lab_data.position = entity.position
    tracking.update_lab(lab_data)
end