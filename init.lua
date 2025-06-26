local S = default.get_translator

local function can_access(pos, player)
    local name = player:get_player_name()
    if core.is_protected(pos, name) and not core.check_player_privs(name, {protection_bypass = true}) then
        core.record_protection_violation(pos, name)
        return false
    end

    return true
end

local function is_book(stack)
    local name = stack:get_name()
    return name == "default:book" or name == "default:book_written"
end

local max_text_size = 40000
local max_title_size = 80
local short_title_size = 35

local function write_book(stack_meta, author, title, text)
    local data = {}
    data.title = title:sub(1, max_title_size)
    data.owner = author
    local short_title = data.title
    -- Don't bother trimming the title if the trailing dots would make it longer
    if #short_title > short_title_size + 3 then
        short_title = short_title:sub(1, short_title_size) .. "..."
    end
    data.description = S("\"@1\" by @2", short_title, data.owner)
    data.text = text:sub(1, max_text_size)
    data.text = data.text:gsub("\r\n", "\n"):gsub("\r", "\n")
    data.text = data.text:gsub("[%z\1-\8\11-\31\127]", "") -- strip naughty control characters (keeps \t and \n)
    data.page = 1
    data.page_max = math.ceil((#data.text:gsub("[^\n]", "") + 1) / 14)

    stack_meta:from_table({fields = data})
end

local function on_digiline_receive(pos, _, channel, msg)
    local meta = core.get_meta(pos)
    if channel ~= meta:get_string("channel") then return end

    local command = msg.command
    local slot = msg.slot or msg.slot1
    if type(command) ~= "string" then return end
    if type(slot) ~= "number" or slot < 1 or slot > 8 then return end
    local inv = meta:get_inventory()
    local stack = inv:get_stack("main", slot)
    if stack:is_empty() then return end
    local stack_meta = stack:get_meta()

    if command == "read" then
        local fields = stack_meta:to_table().fields

        digiline:receptor_send(pos, digilines.rules.default, channel, {
            title = fields.title or "",
            author = fields.owner or "",
            pages = tonumber(fields.pages) or 0,
            text = fields.text or ""
        })

    elseif command == "write" then
        if type(msg.title) ~= "string" or type(msg.text) ~= "string" then
            return
        end

        stack:replace("default:book_written")
        write_book(stack_meta,
            meta:get_string("owner"),
            msg.title or "",
            msg.text or ""
        )
        inv:set_stack("main", slot, stack)

    elseif command == "copy" or command == "swap" then
        local slot2 = msg.slot2
        if type(slot2) ~= "number" or slot2 < 1 or slot2 > 8 then return end
        local stack2 = inv:get_stack("main", slot2)

        if command == "copy" then
            if stack:get_name() == "default:book" or stack2:is_empty() then return end

            local fields = stack_meta:to_table().fields
            stack2:replace("default:book_written")
            write_book(stack2:get_meta(),
                meta:get_string("owner"),
                fields.title or "",
                fields.text or ""
            )
            inv:set_stack("main", slot2, stack2)

        elseif command == "swap" then
            inv:set_stack("main", slot2, stack)
            inv:set_stack("main", slot, stack2)
        end

    elseif command == "clear" then
        if stack:get_name() ~= "default:book_written" then return end

        stack:replace("default:book")
        stack_meta:from_table({})
        inv:set_stack("main", slot, stack)

    elseif command == "eject" then
        local x_velocity = 0
        local z_velocity = 0
        local param2 = core.get_node(pos).param2

        if param2 == 3 then z_velocity = -1 end
        if param2 == 2 then x_velocity = 1 end
        if param2 == 1 then z_velocity = 1 end
        if param2 == 0 then x_velocity = -1 end
        local velocity = vector.new(x_velocity, 0, z_velocity)
        pipeworks.tube_inject_item(pos, pos, velocity, stack:to_table())

        stack:clear()
        inv:set_stack("main", slot, stack)
    end
end

local texture_base = "default_coniferous_litter.png^[contrast:-50^[hsl:0:-100:-80"
local side_texture = texture_base .. "^pipeworks_tube_connection_metallic.png"
local front_texture = texture_base .. "^(book_silhouette.png^[contrast:0:-60^[opacity:200)"

core.register_node("scanner:scanner", {
    description = "Scanner",
    paramtype2 = "facedir",
    is_ground_content = false,
    groups = {
        snappy = 2, choppy = 2, oddly_breakable_by_hand = 1,
        tubedevice = 1, tubedevice_receiver = 1, digtron_protected = 1
    },
    _digistuff_channelcopier_fieldname = "channel",

    tiles = {
        texture_base, texture_base, side_texture,
        side_texture, texture_base, front_texture
    },

    tube = {
        insert_object = function(pos, node, stack)
            if not is_book(stack) then return stack end

            local meta = core.get_meta(pos)
            local inv = meta:get_inventory()

            for i = 1, 8 do
                if stack:is_empty() then break end
                if inv:get_stack("main", i):is_empty() then
                    inv:set_stack("main", i, stack:take_item(1))
                end
            end

            return stack
        end,

        can_insert = function(_, _, stack) return is_book(stack) end,
        input_inventory = "main",
        connect_sides = {left = 1, right = 1}
    },

    digilines = {
        receptor = {},
        effector = {action = on_digiline_receive}
    },

    on_construct = function(pos)
        local meta = core.get_meta(pos)
        local inv = meta:get_inventory()
        inv:set_size("main", 8)
        meta:set_string("formspec",
            "size[8,8]" ..
            "real_coordinates[]" ..
            "label[0,0;Scanner]" ..
            "list[context;main;0,1;8,1;]" ..
            "list[current_player;main;0,4;8,4;]" ..
            "listring[]" ..
            "image[0,1;1,1;book_silhouette.png]" ..
            "image[1,1;1,1;book_silhouette.png]" ..
            "image[2,1;1,1;book_silhouette.png]" ..
            "image[3,1;1,1;book_silhouette.png]" ..
            "image[4,1;1,1;book_silhouette.png]" ..
            "image[5,1;1,1;book_silhouette.png]" ..
            "image[6,1;1,1;book_silhouette.png]" ..
            "image[7,1;1,1;book_silhouette.png]" ..
            "field[0.3,2.8;3,1;channel;Channel;${channel}]" ..
            "button_exit[3,2.5;2,1;set_channel;Set]"
        )
    end,

    after_place_node = function(pos, placer)
        core.get_meta(pos):set_string("owner", placer:get_player_name())
    end,

    can_dig = function(pos, player)
        return can_access(pos, player) and core.get_meta(pos):get_inventory():is_empty("main")
    end,

    on_receive_fields = function(pos, formname, fields, sender)
        if not can_access(pos, sender) then
            return
        end

        if fields.channel then
            core.get_meta(pos):set_string("channel", fields.channel)
        end
    end,

    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        if not can_access(pos, player) then
            return 0
        end

        if from_list ~= "main" or to_list ~= "main" then
            return count
        end

        local inv = core.get_meta(pos):get_inventory()
        return inv:get_stack("main", to_index):is_empty() and 1 or 0
    end,

    allow_metadata_inventory_put = function(pos, _, index, stack, player)
        local inv = core.get_meta(pos):get_inventory()
        if not (can_access(pos, player) and inv:get_stack("main", index):is_empty()) then
            return 0
        end

        local inv = core.get_meta(pos):get_inventory()
        local name = stack:get_name()
        return (name == "default:book" or name == "default:book_written") and 1 or 0
    end,

    allow_metadata_inventory_take = function(pos, _, _, _, player)
        return can_access(pos, player) and 1 or 0
    end
})

core.register_craft({
    output = "scanner:scanner",
    recipe = {
        {"default:glass",       "dye:black",                   "default:glass"},
        {"pipeworks:tube_1",    "basic_materials:motor",       "pipeworks:tube_1"},
        {"default:steel_ingot", "digilines:wire_std_00000000", "default:steel_ingot"}
    }
})
