require("ui.elements.titlebar")
require("ui.elements.subfactory_list")
require("ui.elements.subfactory_info")
require("ui.elements.item_boxes")
require("ui.elements.view_state")

main_dialog = {}

local subfactory_list_width = 300

-- ** LOCAL UTIL **
local function determine_main_dialog_dimensions(player)
    local player_table = data_util.get("table", player)

    local products_per_row = player_table.settings.products_per_row
    local boxes_width_1 = (products_per_row * 40 * 2) + (2*12)
    local boxes_width_2 = ((products_per_row * 40) + (2*12)) * 2
    local width = subfactory_list_width + boxes_width_1 + boxes_width_2 + (2*12) + (3*10)

    local height = (player_table.settings.subfactory_list_rows * 28) + 58

    local dimensions = {width=width, height=height}
    player_table.ui_state.main_dialog_dimensions = dimensions
    return dimensions
end

-- No idea how to write this so it works when in selection mode
local function handle_other_gui_opening(player)
    local frame_main_dialog = data_util.get("main_elements", player).main_frame
    if frame_main_dialog and frame_main_dialog.visible then
        frame_main_dialog.visible = false
        main_dialog.set_pause_state(player, frame_main_dialog)
    end
end


-- ** TOP LEVEL **
main_dialog.gui_events = {
    on_gui_closed = {
        {
            name = "fp_frame_main_dialog",
            handler = (function(player, _)
                main_dialog.toggle(player)
            end)
        }
    },
    on_gui_click = {
        {
            name = "fp_button_toggle_interface",
            handler = (function(player, _, _)
                main_dialog.toggle(player)
            end)
        }
    }
}

main_dialog.misc_events = {
    on_gui_opened = (function(player, _)
        handle_other_gui_opening(player)
    end),

    on_player_display_resolution_changed = (function(player, _)
        main_dialog.rebuild(player, false)
    end),

    on_player_display_scale_changed = (function(player, _)
        main_dialog.rebuild(player, false)
    end),

    on_lua_shortcut = (function(player, event)
        if event.prototype_name == "fp_open_interface" then
            main_dialog.toggle(player)
        end
    end),

    fp_toggle_main_dialog = (function(player, _)
        main_dialog.toggle(player)
    end)
}


function main_dialog.rebuild(player, default_visibility)
    local ui_state = data_util.get("ui_state", player)
    local main_elements = ui_state.main_elements

    local visible = default_visibility
    if main_elements.main_frame ~= nil then
        visible = main_elements.main_frame.visible
        main_elements.main_frame.destroy()

        -- Reset all main element references
        ui_state.main_elements = {}
        main_elements = ui_state.main_elements
    end
    main_elements.flows = {}

    -- Create and configure the top-level frame
    local frame_main_dialog = player.gui.screen.add{type="frame", name="fp_frame_main_dialog",
      visible=visible, direction="vertical"}
    main_elements["main_frame"] = frame_main_dialog

    local dimensions = determine_main_dialog_dimensions(player)
    frame_main_dialog.style.width = dimensions.width
    frame_main_dialog.style.height = dimensions.height
    ui_util.properly_center_frame(player, frame_main_dialog, dimensions.width, dimensions.height)

    if visible then player.opened = frame_main_dialog end
    main_dialog.set_pause_state(player, frame_main_dialog)

    -- Create the actual dialog structure
    view_state.refresh_state(player)  -- actually initializes it
    titlebar.build(player)

    local main_horizontal = frame_main_dialog.add{type="flow", direction="horizontal"}
    main_horizontal.style.horizontal_spacing = 10
    main_elements.flows["main_horizontal"] = main_horizontal

    local left_vertical = main_horizontal.add{type="flow", direction="vertical"}
    left_vertical.style.width = subfactory_list_width
    left_vertical.style.vertical_spacing = 12
    main_elements.flows["left_vertical"] = left_vertical
    subfactory_list.build(player)
    subfactory_info.build(player)

    local right_vertical = main_horizontal.add{type="flow", direction="vertical"}
    right_vertical.style.vertical_spacing = 12
    main_elements.flows["right_vertical"] = right_vertical
    item_boxes.build(player)

    titlebar.refresh_message(player)
end

function main_dialog.refresh(player, element_list)
    view_state.refresh_state(player)
    -- TODO do proper partial refreshing using the element_list
    subfactory_list.refresh(player)
    subfactory_info.refresh(player)

    item_boxes.refresh(player)

    titlebar.refresh_message(player)
end

function main_dialog.toggle(player)
    local ui_state = data_util.get("ui_state", player)
    local frame_main_dialog = ui_state.main_elements.main_frame

    if frame_main_dialog == nil then
        main_dialog.rebuild(player, true)  -- sets opened and paused-state itself

    elseif ui_state.modal_dialog_type == nil then  -- don't toggle if modal dialog is open
        frame_main_dialog.visible = not frame_main_dialog.visible
        player.opened = (frame_main_dialog.visible) and frame_main_dialog or nil

        main_dialog.set_pause_state(player, frame_main_dialog)
        titlebar.refresh_message(player)
    end
end


-- Returns true when the main dialog is open while no modal dialogs are
function main_dialog.is_in_focus(player)
    local frame_main_dialog = data_util.get("main_elements", player).main_frame
    return (frame_main_dialog ~= nil and frame_main_dialog.visible
      and data_util.get("ui_state", player).modal_dialog_type == nil)
end

-- Sets the game.paused-state as is appropriate
function main_dialog.set_pause_state(player, frame_main_dialog, force_false)
    if not game.is_multiplayer() and player.controller_type ~= defines.controllers.editor then
        if data_util.get("preferences", player).pause_on_interface and not force_false then
            game.tick_paused = frame_main_dialog.visible  -- only pause when the main dialog is open
        else
            game.tick_paused = false
        end
    end
end