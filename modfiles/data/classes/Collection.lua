-- 'Class' representing a list of objects/datasets with some useful methods
-- (An object only becomes a dataset once it is added to the collection)
Collection = {}

function Collection.init(object_class)
    return {
        datasets = {},
        index = 0,
        count = 0,
        object_class = object_class,  -- class of the objects in this collection
        class = "Collection"
    }
end


function Collection.add(self, object)
    self.index = self.index + 1
    self.count = self.count + 1
    object.id = self.index
    object.gui_position = self.count
    self.datasets[self.index] = object
    return object  -- Returning it here feels nice
end

function Collection.remove(self, dataset)
    -- Move positions of datasets after the deleted one down by one
    for _, d in pairs(self.datasets) do
        if d.gui_position > dataset.gui_position then
            d.gui_position = d.gui_position - 1
        end
    end

    self.count = self.count - 1
    self.datasets[dataset.id] = nil

    -- Returning the deleted position here to allow for GUI adjustments
    return dataset.gui_position
end

-- Replaces the dataset with the new object in-place
function Collection.replace(self, dataset, object)
    object.parent = dataset.parent
    object.id = dataset.id
    object.gui_position = dataset.gui_position
    self.datasets[dataset.id] = object
    return object  -- Returning it here feels nice
end


function Collection.get(self, object_id)
    return self.datasets[object_id]
end

-- Return format: {[gui_position] = dataset}
function Collection.get_in_order(self, reverse)
    local ordered_datasets = {}
    for _, dataset in pairs(self.datasets) do
        local table_position = (reverse) and (self.count - dataset.gui_position + 1) or dataset.gui_position
        ordered_datasets[table_position] = dataset
    end
    return ordered_datasets
end

-- Returns the dataset specified by the gui_position
function Collection.get_by_gui_position(self, gui_position)
    if gui_position == 0 then return nil end
    for _, dataset in pairs(self.datasets) do
        if dataset.gui_position == gui_position then
            return dataset
        end
    end
end

-- Returns the dataset with the given name, nil if it doesn't exist
function Collection.get_by_name(self, name)
    for _, dataset in pairs(self.datasets) do
        -- Check against the prototype, if it exists
        local check_against = dataset.proto or dataset
        if check_against.name == name then
            return dataset
        end
    end
    return nil
end

-- Returns the dataset with the given type and name, nil if it doesn't exist
function Collection.get_by_type_and_name(self, type_name, name)
    for _, dataset in pairs(self.datasets) do
        -- Check against the prototype, if it exists
        local check_against = dataset.proto or dataset
        if check_against.type == type_name and check_against.name == name then
            return dataset
        end
    end
    return nil
end


-- Does the actual hard lifting of changing the position of a collection element
local function shift_dataset(self, main_dataset, secondary_gui_position, direction)
    local main_gui_position = main_dataset.gui_position

    -- Doesn't shift if outmost elements are being shifted further outward
    if (main_gui_position == 1 and direction == "negative") or
      (main_gui_position == self.count and direction == "positive") then
        return false
    end

    local secondary_dataset = Collection.get_by_gui_position(self, secondary_gui_position)
    main_dataset.gui_position = secondary_gui_position
    secondary_dataset.gui_position = main_gui_position

    return true
end

-- Shifts given dataset in given direction
function Collection.shift(self, main_dataset, direction)
    local main_gui_position = main_dataset.gui_position
    local secondary_gui_position = (direction == "positive") and (main_gui_position + 1) or (main_gui_position - 1)
    return shift_dataset(self, main_dataset, secondary_gui_position, direction)
end

-- Shifts the given dataset to the end of the collection in the given direction
function Collection.shift_to_end(self, main_dataset, direction)
    local secondary_gui_position = (direction == "positive") and self.count or 1
    return shift_dataset(self, main_dataset, secondary_gui_position, direction)
end


-- Updates the validity of all datasets in this collection
function Collection.validate_datasets(self)
    local valid = true
    local object_class = _G[self.object_class]

    for _, dataset in pairs(self.datasets) do
        -- Stays true until a single dataset is invalid, then stays false
        valid = object_class.validate(dataset) and valid
    end

    return valid
end

-- Removes any invalid, unrepairable datasets from the collection
function Collection.repair_datasets(self, player)
    local object_class = _G[self.object_class]

    for _, dataset in pairs(self.datasets) do
        if not dataset.valid and not object_class.repair(dataset, player) then
            _G[dataset.parent.class].remove(dataset.parent, dataset)
        end
    end
end