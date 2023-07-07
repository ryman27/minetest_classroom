--- Returns a list containing the names of the given player's saved coordinates
local function get_saved_coords(player)
    local pmeta = player:get_meta()
    local realm = Realm.GetRealmFromPlayer(player)
    local pdata = minetest.deserialize(pmeta:get_string("coordinates"))
    local context = mc_teacher.get_fs_context(player)
    local coord_list = {}

    if pdata == nil or pdata == {} then
        context.coord_i_to_note = {}
        return coord_list
    elseif pdata.realms then
        local new_note_map, new_coords, new_realms = {}, {}, {}
        context.coord_i_to_note = {}

        for note,i in pairs(pdata.note_map) do
            local coordrealm = Realm.GetRealm(pdata.realms[i])
            if coordrealm then
                -- Do not include coordinates saved in other realms in output
                if realm and coordrealm.ID == realm.ID and note ~= "" then
                    table.insert(coord_list, note)
                    context.coord_i_to_note[#coord_list] = note
                end
                -- Remove coordinates saved in realms that no longer exist from database
                table.insert(new_coords, pdata.coords[i])
                table.insert(new_realms, pdata.realms[i])
                new_note_map[note] = #new_coords
            end
        end

        pmeta:set_string("coordinates", minetest.serialize({note_map = new_note_map, coords = new_coords, realms = new_realms, format = 2}))
        return coord_list
    end
end

local function get_options_height(context)
    if (not context.realm_gen or context.realm_gen == mc_teacher.R.GEN.NONE) and (not context.realm_dec or context.realm_dec == mc_teacher.R.DEC.NONE) then
        return 2.6
    elseif context.realm_dec == mc_teacher.R.DEC.BIOME then
        return 5.2
    else
        return 3.9
    end
end

local function get_privs(player)
    local pmeta = player:get_meta()
    local privs = minetest.get_player_privs(player:get_player_name())
    local universal_privs = minetest.deserialize(pmeta:get_string("universalPrivs")) or {}

    for k, v in pairs(universal_privs) do
        if v == false then
            privs[k] = (privs[k] and "overridden") or false
        end
    end
    return privs
end

local function generate_player_table(p_list, p_priv_list)
    local privs_to_check = {"shout", "interact", "fast", "fly", "noclip", "give"}
    local combined_list = {}
    -- TODO: create new images for other priv statustes
    for i, player in ipairs(p_list) do
        for j, priv in ipairs(privs_to_check) do
            if p_priv_list[i][priv] == true then
                table.insert(combined_list, 1)
            elseif p_priv_list[i][priv] == false then
                table.insert(combined_list, 0--[[2]])
            elseif p_priv_list[i][priv] == "overridden" then
                table.insert(combined_list, 1--[[3]])
            else
                table.insert(combined_list, 0)
            end
        end
        table.insert(combined_list, player)
    end
    return table.concat(combined_list, ",")
end

function mc_teacher.show_confirm_popup(player, fs_name, action, size)
    local spacer = 0.6
    local text_spacer = 0.55
    local width = math.max(size and size.x or 7.5, 1.5)
    local height = math.max(size and size.y or 3.4, 2.1)
    local button_width = (width - 1.3)/2

    local pname = player:get_player_name()
    
    local fs = {
        "formspec_version[6]",
        "size[", width, ",", height, "]",
        "style_type[textarea;font=mono]",
        "style_type[button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
        "textarea[", text_spacer, ",0.5;", width - 2*text_spacer, ",", height - 2, ";;;", action and action.action or "Are you sure you want to perform this action?",
        action.irreversible and "\nThis action is irreversible." or "", "]",
        "button[", spacer, ",", height - 1.4, ";", button_width, ",0.8;confirm;", action and action.button or "Confirm", "]",
        "button[", spacer + 0.1 + button_width, ",", height - 1.4, ";", button_width, ",0.8;cancel;Cancel]",
    }
    minetest.show_formspec(pname, "mc_teacher:"..fs_name, table.concat(fs, ""))
end

function mc_teacher.show_controller_fs(player, tab)
    local controller_width = 16.6
    local controller_height = 10.4
    local panel_width = controller_width/2
    local spacer = 0.6
    local text_spacer = 0.55

    local pname = player:get_player_name()
    local pmeta = player:get_meta()
    local context = mc_teacher.get_fs_context(player)

    if mc_core.checkPrivs(player) then
        local has_server_privs = mc_core.checkPrivs(player, {server = true})
        local tab_map = {
            [mc_teacher.TABS.OVERVIEW] = function()
                local button_width = 1.7
                local button_height = 1.6
                local rules = mc_rules.meta:get_string("rules")
                if not rules or rules == "" then
                    rules = "Rules have not yet been set for this server."
                end

                local Y_SIZE, FACTOR = controller_height - 0.5, 0.05
                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Overview</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Dashboard</b></center></style>]",

                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "style_type[button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Welcome to Minetest Classroom!]",
                    "textarea[", text_spacer, ",4.4;", panel_width - 2*text_spacer, ",1;;;Server Rules]",
                    "style_type[textarea;font=mono]",
                    "textarea[", text_spacer, ",1.5;", panel_width - 2*text_spacer, ",2.6;;;", minetest.formspec_escape("This is the Teacher Controller, your tool for managing classrooms, player privileges, and server settings."),
                    "\n", minetest.formspec_escape("You cannot drop this tool, so you will never lose it. However, you can move it out of your hotbar and into your inventory or the toolbox."), "]",
                    "textarea[", text_spacer, ",4.9;", panel_width - 2*text_spacer, ",", has_server_privs and 4 or 4.9, ";;;", minetest.formspec_escape(rules), "]",
                    has_server_privs and "button[0.6,9;7,0.8;server_edit_rules;Edit server rules]" or "",

                    "scrollbaroptions[min=0;max=", (11.6 + (has_server_privs and 1.7 or 0) - Y_SIZE)/FACTOR, ";smallstep=", 0.8/FACTOR, ";largestep=", 4.8/FACTOR, ";thumbsize=", 1/FACTOR, "]",
                    "scrollbar[", controller_width - 0.3, ",0.5;0.3,", Y_SIZE, ";vertical;overviewscroll;", context.overviewscroll or 0, "]",
                    "scroll_container[", panel_width, ",0.5;", panel_width - 0.3, ",", Y_SIZE, ";overviewscroll;vertical;", FACTOR, "]",

                    "image_button[", spacer, ",0.5;", button_width, ",", button_height, ";mc_teacher_classrooms.png;classrooms;;false;false]",
                    "hypertext[", spacer + 1.8, ",0.8;5.35,1.6;;<style color=#000000><b>Classrooms</b>\n", minetest.formspec_escape("Create and manage classrooms"), "</style>]",
                    "image_button[", spacer, ",2.3;", button_width, ",", button_height, ";mc_teacher_map.png;map;;false;false]",
                    "hypertext[", spacer + 1.8, ",2.6;5.35,1.6;;<style color=#000000><b>Map</b>\n", minetest.formspec_escape("Record and share locations"), "</style>]",
                    "image_button[", spacer, ",4.1;", button_width, ",", button_height, ";mc_teacher_players.png;players;;false;false]",
                    "hypertext[", spacer + 1.8, ",4.4;5.35,1.6;;<style color=#000000><b>Players</b>\n", minetest.formspec_escape("Manage player privileges"), "</style>]",
                    "image_button[", spacer, ",5.9;", button_width, ",", button_height, ";mc_teacher_isometric_crop.png;moderation;;false;false]",
                    "hypertext[", spacer + 1.8, ",6.2;5.35,1.6;;<style color=#000000><b>Moderation</b>\n", minetest.formspec_escape("View player chat logs"), "</style>]",
                    "image_button[", spacer, ",7.7;", button_width, ",", button_height, ";mc_teacher_isometric_crop.png;reports;;false;false]",
                    "hypertext[", spacer + 1.8, ",8;5.35,1.6;;<style color=#000000><b>Reports</b>\n", minetest.formspec_escape("View and resolve player reports"), "</style>]",
                    "image_button[", spacer, ",9.5;", button_width, ",", button_height, ";mc_teacher_help.png;help;;false;false]",
                    "hypertext[", spacer + 1.8, ",9.8;5.35,1.6;;<style color=#000000><b>Help</b>\n", minetest.formspec_escape("View guides and resources"), "</style>]",
                }

                if has_server_privs then
                    table.insert(fs, table.concat({
                        "image_button[", spacer, ",11.3;", button_width, ",", button_height, ";mc_teacher_isometric_crop.png;server;;false;false]",
                        "hypertext[", spacer + 1.8, ",11.6;5.35,1.6;;<style color=#000000><b>Server</b>\n", minetest.formspec_escape("Manage server settings"), "</style>]",
                    }))
                end
                table.insert(fs, "scroll_container_end[]")

                return fs
            end,
            [mc_teacher.TABS.CLASSROOMS] = function()
                local classroom_list = {}
                local realm_count = 1
                local options_height = (context.selected_mode == mc_teacher.MODES.EMPTY and get_options_height(context)) or 1.3
                local FACTOR = 0.1
                context.realm_id_to_i = {}

                Realm.ScanForPlayerRealms()
                for id, realm in pairs(Realm.realmDict or {}) do
                    local playerCount = tonumber(realm:GetPlayerCount())
                    table.insert(classroom_list, table.concat({minetest.formspec_escape(realm.Name or ""), " (", playerCount, " player", playerCount == 1 and "" or "s", ")"}))
                    context.realm_id_to_i[tostring(id)] = realm_count
                    realm_count = realm_count + 1
                end

                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Classrooms</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Build a Classroom</b></center></style>]",

                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "style_type[button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    "style[editrealm;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",
                    "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Available Classrooms]",
                    "textlist[", spacer, ",1.4;", panel_width - 2*spacer, ",7.5;classroomlist;", table.concat(classroom_list, ","), ";", context.realm_id_to_i and context.realm_id_to_i[context.selected_realm_id] or 1, ";false]",
                    "button[", spacer, ",9;2.3,0.8;teleportrealm;Teleport]",
                    "button[", spacer + 2.4, ",9;2.3,0.8;editrealm;Edit]",
                    "button[", spacer + 4.8, ",9;2.3,0.8;deleterealm;Delete]",

                    "style_type[field;font=mono;textcolor=#ffffff]",
                    "scrollbaroptions[min=0;max=", (options_height - 0.7)/FACTOR, ";smallstep=", 0.6/FACTOR, ";largestep=", 3.6/FACTOR, ";thumbsize=", 0.6/FACTOR, "]",
                    "scrollbar[", controller_width - 0.3, ",1;0.3,", controller_height - 2.5, ";vertical;class_opt_scroll;", context.class_opt_scroll or 0, "]",
                    "scroll_container[", panel_width, ",1;", panel_width - 0.3, ",", controller_height - 2.5, ";class_opt_scroll;vertical;", FACTOR, "]",

                    "textarea[", text_spacer, ",0;", panel_width - 2*text_spacer, ",1;;;Name]",
                    "field[", spacer, ",0.4;7.1,0.8;realmname;;", context.realmname or "", "]",
                    "field_close_on_enter[realmname;false]",
                    "textarea[", text_spacer, ",1.25;3.6,1;;;Type]",
                    "dropdown[", spacer, ",1.7;3.5,0.8;realmcategory;Default,Spawn,Classroom,Instanced" or "", ";", context.selected_realm_type or 1, ";true]",
                    "textarea[", text_spacer + 3.6, ",1.25;3.6,1;;;Generation]",
                    "dropdown[", spacer + 3.6, ",1.7;3.5,0.8;mode;Empty World,Schematic,Digital Twin" or "", ";", context.selected_mode or 1, ";true]",
                }

                if context.selected_mode == mc_teacher.MODES.EMPTY then
                    table.insert(fs, table.concat({
                        "textarea[", text_spacer, ",2.6;", panel_width - 2*text_spacer, ",1;;;Classroom Size]",
                        "textarea[", text_spacer, ",3.2;1,1;;;X =]",
                        "textarea[", text_spacer + 2.4, ",3.2;1,1;;;Y =]",
                        "textarea[", text_spacer + 4.8, ",3.2;1,1;;;Z =]",
                        "field[", spacer + 0.9, ",3;1.3,0.8;realm_x_size;;", context.realm_x or 80, "]",
                        "field[", spacer + 3.3, ",3;1.3,0.8;realm_y_size;;", context.realm_y or 80, "]",
                        "field[", spacer + 5.7, ",3;1.3,0.8;realm_z_size;;", context.realm_z or 80, "]",
                        "textarea[", text_spacer, ",3.9;3.6,1;;;Terrain Generator]",
                        "textarea[", text_spacer + 3.6, ",3.9;3.6,1;;;Terrain Decorator]",
                        "dropdown[", spacer, ",4.3;3.5,0.8;realm_generator;None,Version 1,Version 2,DNR;", context.realm_gen or 1, ";true]",
                        "dropdown[", spacer + 3.6, ",4.3;3.5,0.8;realm_decorator;None,Version 1,Version 2,Biomegen;", context.realm_dec or 1, ";true]",
                    
                        "field_close_on_enter[realm_x_size;false]",
                        "field_close_on_enter[realm_y_size;false]",
                        "field_close_on_enter[realm_z_size;false]",
                    }))

                    -- TODO: link generators, decorators, BEC biomes to realm generation
                    if options_height >= 3.9 then
                        table.insert(fs, table.concat({
                            "textarea[", text_spacer, ",5.2;3.6,1;;;Seed]",
                            "textarea[", text_spacer + 3.6, ",5.2;3.6,1;;;Sea Level]",
                            "field[", spacer, ",5.6;3.5,0.8;realm_seed;;", minetest.formspec_escape(context.realm_seed) or "", "]",
                            "field[", spacer + 3.6, ",5.6;3.5,0.8;realm_sealevel;;", minetest.formspec_escape(context.realm_sealevel) or "", "]",

                            "field_close_on_enter[realm_seed;false]",
                            "field_close_on_enter[realm_sealevel;false]",
                        }))
                    end
                    if options_height >= 5.2 then
                        table.insert(fs, table.concat({
                            "textarea[", text_spacer, ",6.5;3.6,1;;;Biome]",
                            "textarea[", text_spacer + 3.6, ",6.5;3.6,1;;;Chill Coefficient]",
                            "dropdown[", spacer, ",6.9;3.5,0.8;realm_biome;;1;false]",
                            "field[", spacer + 3.6, ",6.9;3.5,0.8;realm_chill;;", minetest.formspec_escape(context.realm_chill) or "", "]",

                            "field_close_on_enter[realm_chill;false]",
                        }))
                    end
                elseif context.selected_mode == mc_teacher.MODES.SCHEMATIC then
                    local schematics = {}
                    local name_to_i = {}
                    local ctr = 1
                    for name, path in pairs(schematicManager.schematics) do
                        if ctr == 1 and not context.selected_schematic then
                            context.selected_schematic = name
                        end
                        table.insert(schematics, name)
                        name_to_i[name] = ctr
                        ctr = ctr + 1
                    end
                    context.name_to_i = name_to_i

                    table.insert(fs, table.concat({
                        "textarea[", text_spacer, ",2.6;", panel_width - 2*text_spacer, ",1;;;Schematic]",
                        "dropdown[", spacer, ",3;", panel_width - 2*spacer, ",0.8;schematic;", table.concat(schematics, ","), ";", context.name_to_i[context.selected_schematic] or 1, ";false]",
                    }))
                elseif context.selected_mode == mc_teacher.MODES.TWIN then
                    local twins = {}
                    local name_to_i = {}
                    local ctr = 1
                    for name, path in pairs(realterrainManager.dems) do
                        if ctr == 1 and not context.selected_dem then
                            context.selected_dem = name
                        end
                        table.insert(twins, name)
                        name_to_i[name] = ctr
                        ctr = ctr + 1
                    end
                    context.name_to_i = name_to_i

                    table.insert(fs, table.concat({
                        "textarea[", text_spacer, ",2.6;", panel_width - 2*text_spacer, ",1;;;Digital Twin World]",
                        "dropdown[", spacer, ",3;", panel_width - 2*spacer, ",0.8;realterrain;", table.concat(twins, ","), ";", context.name_to_i[context.selected_dem] or 1, ";false]",
                    }))
                else
                    table.insert(fs, table.concat({
                        "textarea[", text_spacer, ",2.6;", panel_width - 2*text_spacer, ",1.2;;;Select a generation mode for more options!]",
                    }))
                end

                table.insert(fs, table.concat({
                    "container[0,", 2.6 + options_height, "]",
                    "textarea[", text_spacer, ",0;", panel_width - 2*text_spacer, ",1;;;Default Privileges]",
                    "style_type[textarea;font=mono]",
                    "textarea[", text_spacer + 1.3, ",0.8;1.9,1;;;interact]",
                    "textarea[", text_spacer + 1.3, ",1.2;1.9,1;;;shout]",
                    "textarea[", text_spacer + 1.3, ",1.6;1.9,1;;;fast]",
                    "textarea[", text_spacer + 4.9, ",0.8;1.9,1;;;fly]",
                    "textarea[", text_spacer + 4.9, ",1.2;1.9,1;;;noclip]",
                    "textarea[", text_spacer + 4.9, ",1.6;1.9,1;;;give]",
                    "image[", text_spacer, ",0.4;0.4,0.4;mc_teacher_allowpriv.png]",
                    "image[", text_spacer + 0.4, ",0.4;0.4,0.4;mc_teacher_ignorepriv.png]",
                    "image[", text_spacer + 0.8, ",0.4;0.4,0.4;mc_teacher_denypriv.png]",
                    "image[", text_spacer + 3.6, ",0.4;0.4,0.4;mc_teacher_allowpriv.png]",
                    "image[", text_spacer + 4.0, ",0.4;0.4,0.4;mc_teacher_ignorepriv.png]",
                    "image[", text_spacer + 4.4, ",0.4;0.4,0.4;mc_teacher_denypriv.png]",
                    "tooltip[", text_spacer, ",0.4;0.4,0.4;ALLOW: Privilege will be granted\n(does NOT override universal privileges);#404040;#ffffff]",
                    "tooltip[", text_spacer + 0.4, ",0.4;0.4,0.4;IGNORE: Privilege will be unaffected;#404040;#ffffff]",
                    "tooltip[", text_spacer + 0.8, ",0.4;0.4,0.4;DENY: Privilege will not be granted\n(overrides universal privileges);#404040;#ffffff]",
                    "tooltip[", text_spacer + 3.6, ",0.4;0.4,0.4;ALLOW: Privilege will be granted\n(does NOT override universal privileges);#404040;#ffffff]",
                    "tooltip[", text_spacer + 4.0, ",0.4;0.4,0.4;IGNORE: Privilege will be unaffected;#404040;#ffffff]",
                    "tooltip[", text_spacer + 4.4, ",0.4;0.4,0.4;DENY: Privilege will not be granted\n(overrides universal privileges);#404040;#ffffff]",

                    "checkbox[", spacer, ",1.0;allowpriv_interact;;", tostring(context.selected_privs.interact == true), "]",
                    "checkbox[", spacer, ",1.4;allowpriv_shout;;", tostring(context.selected_privs.shout == true), "]",
                    "checkbox[", spacer, ",1.8;allowpriv_fast;;", tostring(context.selected_privs.fast == true), "]",
                    "checkbox[", spacer + 0.4, ",1.0;ignorepriv_interact;;", tostring(context.selected_privs.interact == "nil"), "]",
                    "checkbox[", spacer + 0.4, ",1.4;ignorepriv_shout;;", tostring(context.selected_privs.shout == "nil"), "]",
                    "checkbox[", spacer + 0.4, ",1.8;ignorepriv_fast;;", tostring(context.selected_privs.fast == "nil"), "]",
                    "checkbox[", spacer + 0.8, ",1.0;denypriv_interact;;", tostring(context.selected_privs.interact == false), "]",
                    "checkbox[", spacer + 0.8, ",1.4;denypriv_shout;;", tostring(context.selected_privs.shout == false), "]",
                    "checkbox[", spacer + 0.8, ",1.8;denypriv_fast;;", tostring(context.selected_privs.fast == false), "]",
                    "checkbox[", spacer + 3.6, ",1.0;allowpriv_fly;;", tostring(context.selected_privs.fly == true), "]",
                    "checkbox[", spacer + 3.6, ",1.4;allowpriv_noclip;;", tostring(context.selected_privs.noclip == true), "]",
                    "checkbox[", spacer + 3.6, ",1.8;allowpriv_give;;", tostring(context.selected_privs.give == true), "]",
                    "checkbox[", spacer + 4.0, ",1.0;ignorepriv_fly;;", tostring(context.selected_privs.fly == "nil"), "]",
                    "checkbox[", spacer + 4.0, ",1.4;ignorepriv_noclip;;", tostring(context.selected_privs.noclip == "nil"), "]",
                    "checkbox[", spacer + 4.0, ",1.8;ignorepriv_give;;", tostring(context.selected_privs.give == "nil"), "]",
                    "checkbox[", spacer + 4.4, ",1.0;denypriv_fly;;", tostring(context.selected_privs.fly == false), "]",
                    "checkbox[", spacer + 4.4, ",1.4;denypriv_noclip;;", tostring(context.selected_privs.noclip == false), "]",
                    "checkbox[", spacer + 4.4, ",1.8;denypriv_give;;", tostring(context.selected_privs.give == false), "]",
                    "container_end[]",

                    "style_type[textarea;font=mono,bold]",
                    "textarea[", text_spacer, ",", 4.7 + options_height, ";", panel_width - 2*text_spacer, ",1;;;Background Music]",
                    "dropdown[", spacer, ",", 5.1 + options_height, ";", panel_width - 2*spacer, ",0.8;bgmusic;None;1;false]",
                    "textarea[", text_spacer, ",", 6 + options_height, ";", panel_width - 2*text_spacer, ",1;;;Skybox]",
                    "dropdown[", spacer, ",", 6.4 + options_height, ";", panel_width - 2*spacer, ",0.8;skybox;Default;1;false]",
                    "scroll_container_end[]",

                    "button[", panel_width + spacer, ",9;", panel_width - 2*spacer, ",0.8;requestrealm;Generate Classroom]",
                }))

                return fs
                -- TODO: Background Music and skyboxes
                -- method: local backgroundSound = realm:get_data("background_sound")]]
            end,
            [mc_teacher.TABS.MAP] = function()
                local map_x = spacer + 0.025
                local map_y = 1.425
                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Map</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Coordinates</b></center></style>]",
                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Surrounding Area]",
                    "image[", map_x - 0.025, ",", map_y - 0.025, ";7.1,7.1;mc_pixel.png^[multiply:#000000]",
                    "image[", map_x, ",", map_y, ";7.05,7.05;mc_pixel.png^[multiply:#808080]",
                }
                
                local bounds = {xmin = -24, xmax = 24, zmin = -24, zmax = 24}
                local mapar = mc_mapper.map_handler(player, bounds)
                for i = 1, bounds.xmax - bounds.xmin - 1, 1 do
                    for j = 1, bounds.zmax - bounds.zmin - 1, 1 do
                        if mapar[i][j].im ~= nil then
                            -- The following for colorbrewer integration
                            if mapar[i][j].pa then
                                local y_im = math.ceil(mapar[i][j].p2/16)
                                local x_im = mapar[i][j].p2-((y_im-1)*16)
                                mapar[i][j].im = mapar[i][j].pa.."_palette.png\\^[sheet\\:16x16:"..tostring(x_im).."\\,"..tostring(y_im) -- double backslash required to first escape lua and then escape the API
                            end
                            if mapar[i][j].y ~= mapar[i][j+1].y then mapar[i][j].im = mapar[i][j].im .. "^(mc_mapper_blockb.png^[transformR180)" end
                            if mapar[i][j].y ~= mapar[i][j-1].y then mapar[i][j].im = mapar[i][j].im .. "^(mc_mapper_blockb.png)" end
                            if mapar[i][j].y ~= mapar[i-1][j].y then mapar[i][j].im = mapar[i][j].im .. "^(mc_mapper_blockb.png^[transformR270)" end
                            if mapar[i][j].y ~= mapar[i+1][j].y then mapar[i][j].im = mapar[i][j].im .. "^(mc_mapper_blockb.png^[transformR90)" end
                            table.insert(fs, table.concat({
                                "image[", map_x + 0.15*(i - 1), ",", map_y + 0.15*(bounds.zmax - bounds.zmin - j - 1),
                                ";0.15,0.15;", mapar[i][j].im, "]";
                            }))
                        end
                    end
                end

                local yaw = player:get_look_yaw()
                local rotate = 0
                if yaw ~= nil then
                    -- Find rotation and texture based on yaw.
                    yaw = math.fmod(mc_mapper.round_to_texture_multiple(math.deg(yaw)), 360)
                    if yaw < 90 then
                        rotate = 90
                    elseif yaw < 180 then
                        rotate = 180
                    elseif yaw < 270 then
                        rotate = 270
                    else
                        rotate = 0
                    end
                    yaw = math.fmod(yaw, 90)
                end
                local pos = player:get_pos()
                local round_px, round_pz = math.round(pos.x), math.round(pos.z)

                table.insert(fs, table.concat({
                    "image[", 3.95 + (pos.x - round_px)*0.15, ",", 4.75 - (pos.z - round_pz)*0.15,
                    ";0.4,0.4;mc_mapper_d", yaw, ".png^[transformFY", rotate ~= 0 and ("R"..rotate) or "", "]",
                    "textarea[", text_spacer, ",8.6;", panel_width - 2*text_spacer, ",1;;;Coordinate and Elevation Display]",
                    "style_type[button,image_button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    "button[", spacer, ",9;1.7,0.8;utmcoords;UTM]",
                    "button[", spacer + 1.8, ",9;1.7,0.8;latloncoords;Lat/Lon]",
                    "button[", spacer + 3.6, ",9;1.7,0.8;classroomcoords;Local]",
                    "button[", spacer + 5.4, ",9;1.7,0.8;coordsoff;Off]",
                    "textarea[", panel_width + text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Saved Coordinates]",
                }))

                local coord_list = get_saved_coords(player)
                table.insert(fs, table.concat({
                    "textlist[", panel_width + spacer, ",1.4;", panel_width - 2*spacer, ",4.8;coordlist;", coord_list and #coord_list > 0 and table.concat(coord_list, ",") or "No coordinates saved!", ";", context.selected_coord or 1, ";false]",
                    coord_list and #coord_list > 0 and "" or "style_type[image_button;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",
                    "image_button[", panel_width + spacer, ",6.3;1.1,1.1;mc_teacher_teleport.png;", coord_list and #coord_list > 0 and "go" or "blocked", ";;false;false]",
                    "image_button[", panel_width + spacer + 1.2, ",6.3;1.1,1.1;mc_teacher_teleport_all.png;", coord_list and #coord_list > 0 and "go_all" or "blocked", ";;false;false]",
                    "image_button[", panel_width + spacer + 2.4, ",6.3;1.1,1.1;mc_teacher_share.png;", coord_list and #coord_list > 0 and "share" or "blocked", ";;false;false]",
                    "image_button[", panel_width + spacer + 3.6, ",6.3;1.1,1.1;mc_teacher_mark.png;", coord_list and #coord_list > 0 and "mark" or "blocked", ";;false;false]",
                    "image_button[", panel_width + spacer + 4.8, ",6.3;1.1,1.1;mc_teacher_delete.png;", coord_list and #coord_list > 0 and "delete" or "blocked", ";;false;false]",
                    "image_button[", panel_width + spacer + 6.0, ",6.3;1.1,1.1;mc_teacher_clear.png;", coord_list and #coord_list > 0 and "clear" or "blocked", ";;false;false]",
                    
                    coord_list and #coord_list > 0 and "" or "style_type[button;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    "textarea[", panel_width + text_spacer, ",8.5;", panel_width - 2*text_spacer, ",1;;;Save current coordinates]",
                    "style_type[textarea;font=mono]",
                    "textarea[", panel_width + text_spacer, ",7.6;", panel_width - 2*text_spacer, ",1;;;SELECTED\nLocal: (X, Y, Z)]",
                    "textarea[", panel_width + spacer, ",8.9;6.2,0.9;note;;]",
                    "style_type[image_button;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    "image_button[15.1,8.9;0.9,0.9;mc_teacher_save.png;record;Save;false;false]",
                    
                    "tooltip[utmcoords;Displays real-world UTM coordinates;#404040;#ffffff]",
                    "tooltip[latloncoords;Displays real-world latitude and longitude;#404040;#ffffff]",
                    "tooltip[classroomcoords;Displays in-game coordinates, relative to the classroom;#404040;#ffffff]",
                    "tooltip[coordsoff;Disables coordinate display;#404040;#ffffff]",
                    "tooltip[go;Teleport to location;#404040;#ffffff]",
                    "tooltip[go_all;Teleport all players to location;#404040;#ffffff]",
                    "tooltip[share;Share location in chat;#404040;#ffffff]",
                    "tooltip[mark;Place marker in world;#404040;#ffffff]",
                    "tooltip[delete;Delete location;#404040;#ffffff]",
                    "tooltip[clear;Clear all saved locations;#404040;#ffffff]",
                    "tooltip[note;Add a note here!;#404040;#ffffff]",
                    "style_type[image_button;bgimg=blank.png]",
                }))

                return fs
            end,
            [mc_teacher.TABS.PLAYERS] = function()
                context.selected_p_tab = context.selected_p_tab or "1"
                context.selected_p_player = context.selected_p_player or 1
                context.selected_p_mode = context.selected_p_mode or mc_teacher.PMODE.SELECTED

                if not context.p_list then
                    context.p_list = {}
                    if context.selected_p_tab == "1" then
                        for student,_ in pairs(mc_teacher.students) do
                            table.insert(context.p_list, student)
                        end
                    elseif context.selected_p_tab == "2" then
                        for teacher,_ in pairs(mc_teacher.teachers) do
                            table.insert(context.p_list, teacher)
                        end
                    elseif context.selected_p_tab == "3" then
                        local this_realm = Realm.GetRealmFromPlayer(player)
                        for _,p in pairs(minetest.get_connected_players() or {}) do
                            if p:is_player() then
                                local p_realm = Realm.GetRealmFromPlayer(p)
                                if this_realm and p_realm and this_realm.ID == p_realm.ID then
                                    table.insert(context.p_list, p:get_player_name())
                                end
                            end
                        end
                    end
                end
                local p_priv_list = {}
                for _,p in ipairs(context.p_list) do
                    local p_obj = minetest.get_player_by_name(p)
                    table.insert(p_priv_list, p_obj and get_privs(p_obj) or {})
                end
                local selected_player = context.p_list[context.selected_p_player]

                local player_privs = {interact = true, shout = true, fast = true, fly = true, noclip = true, give = true}
                if selected_player then
                    local _,missing = minetest.check_player_privs(selected_player, player_privs)
                    if type(missing) == "string" then missing = {missing} end

                    for _,priv in pairs(missing or {}) do
                        player_privs[priv] = false
                    end
                else
                    player_privs = {}
                end

                local base_img = {
                    shout = "mc_teacher_share.png^[resize:25x25", --"mc_teacher_p_shout.png^[resize:25x25",
                    interact = "mc_teacher_isometric_crop.png^[resize:25x25", --"mc_teacher_p_interact.png^[resize:25x25",
                    fast = "mc_teacher_players.png^[resize:25x25", --"mc_teacher_p_fast.png^[resize:25x25",
                    fly = "mc_teacher_teleport.png^[resize:25x25", --"mc_teacher_p_fly.png^[resize:25x25",
                    noclip = "mc_teacher_delete.png^[resize:25x25", --"mc_teacher_p_noclip.png^[resize:25x25",
                    give = "mc_teacher_mark.png^[resize:25x25", --"mc_teacher_p_give.png^[resize:25x25",
                    --blank = "blank.png^[resize:25x25",
                }
                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Players</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Manage Players</b></center></style>]",
                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "style_type[button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    -- TODO: re-implement groups
                    "style[p_group_new,p_group_edit,p_group_delete;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",
                    -- TODO: re-impelment remaining actions
                    "style[p_audience,p_freeze,p_timeout;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",
                    -- TODO: implement role buttons
                    "style[p_role_none,p_role_student,p_role_teacher,p_role_admin;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",
                    "style[p_mode_", context.selected_p_mode == mc_teacher.PMODE.ALL and "all" or context.selected_p_mode == mc_teacher.PMODE.TAB and "tab" or "selected", ";bgimg=mc_pixel.png^[multiply:", mc_core.col.b.selected, "]",
                    
                    "tabheader[", spacer, ",1.4;", panel_width - 2*spacer - 0.35, ",0.5;p_list_header;Students,Teachers,Classroom;", context.selected_p_tab, ";false;true]",
                    "tablecolumns[image,align=center,padding=0.1,tooltip=shout,0=", base_img.shout, "^[opacity:31,1=", base_img.shout, ";",
                                 "image,align=center,padding=0.1,tooltip=interact,0=", base_img.interact, "^[opacity:31,1=", base_img.interact, ";",
                                 "image,align=center,padding=0.1,tooltip=fast,0=", base_img.fast, "^[opacity:31,1=", base_img.fast, ";",
                                 "image,align=center,padding=0.1,tooltip=fly,0=", base_img.fly, "^[opacity:31,1=", base_img.fly, ";",
                                 "image,align=center,padding=0.1,tooltip=noclip,0=", base_img.noclip, "^[opacity:31,1=", base_img.noclip, ";",
                                 "image,align=center,padding=0.1,tooltip=give,0=", base_img.give, "^[opacity:31,1=", base_img.give, ";",
                                 "text]",
                    "table[", spacer, ",1.4;", panel_width - 2*spacer, ",7.5;p_list;", generate_player_table(context.p_list, p_priv_list), ";", context.selected_p_player, "]",
                    
                    "button[", panel_width - spacer - 0.45, ",0.95;0.45,0.45;p_group_new;+]",
                    "button[", spacer, ",9;3.5,0.8;p_group_edit;Edit group]",
                    "button[", spacer + 3.6, ",9;3.5,0.8;p_group_delete;Delete group]",

                    "textarea[", panel_width + text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Action Mode]",
                    "button[", panel_width + spacer, ",1.4;2.3,0.8;p_mode_selected;Selected]",
                    "button[", panel_width + spacer + 2.4, ",1.4;2.3,0.8;p_mode_tab;Tab]",
                    "button[", panel_width + spacer + 4.8, ",1.4;2.3,0.8;p_mode_all;All]",

                    "textarea[", panel_width + text_spacer, ",2.3;", panel_width - 2*text_spacer, ",1;;;Privileges in this Classroom]",
                    "style_type[textarea;font=mono]",
                    "textarea[", panel_width + text_spacer + 1.3, ",3.1;2.3,1;;;interact]",
                    "textarea[", panel_width + text_spacer + 1.3, ",3.5;2.3,1;;;shout]",
                    "textarea[", panel_width + text_spacer + 1.3, ",3.9;2.3,1;;;fast]",
                    "textarea[", panel_width + text_spacer + 4.9, ",3.1;2.3,1;;;fly]",
                    "textarea[", panel_width + text_spacer + 4.9, ",3.5;2.3,1;;;noclip]",
                    "textarea[", panel_width + text_spacer + 4.9, ",3.9;2.3,1;;;give]",
                    "style_type[textarea;font=mono,bold]",
                    "image[", panel_width + text_spacer, ",2.7;0.4,0.4;mc_teacher_allowpriv.png]",
                    "image[", panel_width + text_spacer + 0.4, ",2.7;0.4,0.4;mc_teacher_ignorepriv.png]",
                    "image[", panel_width + text_spacer + 0.8, ",2.7;0.4,0.4;mc_teacher_denypriv.png]",
                    "image[", panel_width + text_spacer + 3.6, ",2.7;0.4,0.4;mc_teacher_allowpriv.png]",
                    "image[", panel_width + text_spacer + 4.0, ",2.7;0.4,0.4;mc_teacher_ignorepriv.png]",
                    "image[", panel_width + text_spacer + 4.4, ",2.7;0.4,0.4;mc_teacher_denypriv.png]",
                }

                -- TODO: reimplement images behind checkboxes
                --[[if player_privs.interact then
                    table.insert(fs, table.concat({"image[", panel_width + spacer - 0.05, ",2.85;0.4,0.4;mc_pixel.png^[multiply:#59a63a]"}))
                end
                if player_privs.shout then
                    table.insert(fs, table.concat({"image[", panel_width + spacer - 0.05, ",3.25;0.4,0.4;mc_pixel.png^[multiply:#59a63a]"}))
                end
                if player_privs.fast then
                    table.insert(fs, table.concat({"image[", panel_width + spacer + 2.35, ",2.85;0.4,0.4;mc_pixel.png^[multiply:#59a63a]"}))
                end
                if player_privs.fly then
                    table.insert(fs, table.concat({"image[", panel_width + spacer + 2.35, ",3.25;0.4,0.4;mc_pixel.png^[multiply:#59a63a]"}))
                end
                if player_privs.noclip then
                    table.insert(fs, table.concat({"image[", panel_width + spacer + 4.75, ",2.85;0.4,0.4;mc_pixel.png^[multiply:#59a63a]"}))
                end
                if player_privs.give then
                    table.insert(fs, table.concat({"image[", panel_width + spacer + 4.75, ",3.25;0.4,0.4;mc_pixel.png^[multiply:#59a63a]"}))
                end]]
                
                table.insert(fs, table.concat({
                    "checkbox[", panel_width + spacer, ",3.3;allowpriv_interact;;", tostring(context.selected_privs.interact == true), "]",
                    "checkbox[", panel_width + spacer, ",3.7;allowpriv_shout;;", tostring(context.selected_privs.shout == true), "]",
                    "checkbox[", panel_width + spacer, ",4.1;allowpriv_fast;;", tostring(context.selected_privs.fast == true), "]",
                    "checkbox[", panel_width + spacer + 0.4, ",3.3;ignorepriv_interact;;", tostring(context.selected_privs.interact == "nil"), "]",
                    "checkbox[", panel_width + spacer + 0.4, ",3.7;ignorepriv_shout;;", tostring(context.selected_privs.shout == "nil"), "]",
                    "checkbox[", panel_width + spacer + 0.4, ",4.1;ignorepriv_fast;;", tostring(context.selected_privs.fast == "nil"), "]",
                    "checkbox[", panel_width + spacer + 0.8, ",3.3;denypriv_interact;;", tostring(context.selected_privs.interact == false), "]",
                    "checkbox[", panel_width + spacer + 0.8, ",3.7;denypriv_shout;;", tostring(context.selected_privs.shout == false), "]",
                    "checkbox[", panel_width + spacer + 0.8, ",4.1;denypriv_fast;;", tostring(context.selected_privs.fast == false), "]",
                    "checkbox[", panel_width + spacer + 3.6, ",3.3;allowpriv_fly;;", tostring(context.selected_privs.fly == true), "]",
                    "checkbox[", panel_width + spacer + 3.6, ",3.7;allowpriv_noclip;;", tostring(context.selected_privs.noclip == true), "]",
                    "checkbox[", panel_width + spacer + 3.6, ",4.1;allowpriv_give;;", tostring(context.selected_privs.give == true), "]",
                    "checkbox[", panel_width + spacer + 4.0, ",3.3;ignorepriv_fly;;", tostring(context.selected_privs.fly == "nil"), "]",
                    "checkbox[", panel_width + spacer + 4.0, ",3.7;ignorepriv_noclip;;", tostring(context.selected_privs.noclip == "nil"), "]",
                    "checkbox[", panel_width + spacer + 4.0, ",4.1;ignorepriv_give;;", tostring(context.selected_privs.give == "nil"), "]",
                    "checkbox[", panel_width + spacer + 4.4, ",3.3;denypriv_fly;;", tostring(context.selected_privs.fly == false), "]",
                    "checkbox[", panel_width + spacer + 4.4, ",3.7;denypriv_noclip;;", tostring(context.selected_privs.noclip == false), "]",
                    "checkbox[", panel_width + spacer + 4.4, ",4.1;denypriv_give;;", tostring(context.selected_privs.give == false), "]",
                    "button[", panel_width + spacer, ",4.4;3.5,0.8;p_priv_update;Update privs]",
                    "button[", panel_width + spacer + 3.6, ",4.4;3.5,0.8;p_priv_reset;Reset privs]",

                    "textarea[", panel_width + text_spacer, ",5.3;", panel_width - 2*text_spacer, ",1;;;Actions]",
                    "button[", panel_width + spacer, ",5.7;2.3,0.8;p_teleport;Teleport]",
                    "button[", panel_width + spacer + 2.4, ",5.7;2.3,0.8;p_bring;Bring]",
                    "button[", panel_width + spacer + 4.8, ",5.7;2.3,0.8;p_audience;Audience]",
                    "button[", panel_width + spacer, ",6.6;2.3,0.8;p_mute;Mute]",
                    "button[", panel_width + spacer + 2.4, ",6.6;2.3,0.8;p_deactivate;Deactivate]",
                    "button[", panel_width + spacer + 4.8, ",6.6;2.3,0.8;p_freeze;Freeze]",
                    "button[", panel_width + spacer, ",7.5;2.3,0.8;p_timeout;Timeout]",
                    "button[", panel_width + spacer + 2.4, ",7.5;2.3,0.8;p_kick;Kick]",
                    "button[", panel_width + spacer + 4.8, ",7.5;2.3,0.8;p_ban;Ban]",
                    
                    "textarea[", panel_width + text_spacer, ",8.4;", panel_width - 2*text_spacer, ",1;;;Server Role]",
                }))

                if not has_server_privs then
                    table.insert(fs, "style[blocked_role_teacher,blocked_role_admin;bgimg=mc_pixel.png^[multiply:"..mc_core.col.b.blocked.."]")
                end
                table.insert(fs, table.concat({
                    "image[", panel_width + spacer, ",8.8;3.5,1;mc_pixel.png^[multiply:#acabff]",
                    "image[", panel_width + spacer + 3.6, ",8.8;3.5,1;mc_pixel.png^[multiply:#f5c987]", --#ffd699
                    "button[", panel_width + spacer + 0.1, ",8.9;1.6,0.8;p_role_none;None]",
                    "button[", panel_width + spacer + 1.8, ",8.9;1.6,0.8;p_role_student;Student]",
                    "button[", panel_width + spacer + 3.7, ",8.9;1.6,0.8;", has_server_privs and "p_role_teacher" or "blocked_role_teacher", ";Teacher]",
                    "button[", panel_width + spacer + 5.4, ",8.9;1.6,0.8;", has_server_privs and "p_role_admin" or "blocked_role_teacher", ";Admin]",
                    
                    "tooltip[p_mode_selected;The selected player;#404040;#ffffff]",
                    "tooltip[p_mode_tab;All players in the selected tab;#404040;#ffffff]",
                    "tooltip[p_mode_all;All online players;#404040;#ffffff]",
                    "tooltip[p_role_none;No privileges\nListed as a student\nCan not use classroom tools;#404040;#ffffff]",
                    "tooltip[p_role_student;Privileges: student\nListed as a student\nCan use student tools;#404040;#ffffff]",
                    "tooltip[", has_server_privs and "p_role_teacher" or "blocked_role_teacher", ";Privileges: student, teacher\nListed as a teacher\nCan use student and teacher tools;#404040;#ffffff]",
                    "tooltip[", has_server_privs and "p_role_admin" or "blocked_role_teacher", ";Privileges: student, teacher, server\nListed as a teacher\nCan use student, teacher, and administrator tools;#404040;#ffffff]",
                    
                    "tooltip[", panel_width + text_spacer, ",2.7;0.4,0.4;ALLOW: Privilege will be granted\n(overrides universal privileges);#404040;#ffffff]",
                    "tooltip[", panel_width + text_spacer + 0.4, ",2.7;0.4,0.4;IGNORE: Privilege will be unaffected;#404040;#ffffff]",
                    "tooltip[", panel_width + text_spacer + 0.8, ",2.7;0.4,0.4;DENY: Privilege will not be granted\n(overrides universal privileges);#404040;#ffffff]",
                    "tooltip[", panel_width + text_spacer + 3.6, ",2.7;0.4,0.4;ALLOW: Privilege will be granted\n(overrides universal privileges);#404040;#ffffff]",
                    "tooltip[", panel_width + text_spacer + 4.0, ",2.7;0.4,0.4;IGNORE: Privilege will be unaffected;#404040;#ffffff]",
                    "tooltip[", panel_width + text_spacer + 4.4, ",2.7;0.4,0.4;DENY: Privilege will not be granted\n(overrides universal privileges);#404040;#ffffff]",
                    "tooltip[p_mute;Revokes the shout privilege globally;#404040;#ffffff]",
                    "tooltip[p_deactivate;Revokes the interact privilege globally;#404040;#ffffff]",
                    "tooltip[p_freeze;Disables player movement;#404040;#ffffff]",
                    "tooltip[p_teleport;Teleports you to the selected player;#404040;#ffffff]",
                    "tooltip[p_bring;Teleports the player to you;#404040;#ffffff]",
                    "tooltip[p_timeout;Teleports the player to spawn and\nprevents them from joining classrooms;#404040;#ffffff]",
                }))

                return fs
            end,
            [mc_teacher.TABS.MODERATION] = function()
                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Moderation</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Message Log</b></center></style>]",
                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "style_type[button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                }

                local chat_msg = minetest.deserialize(mc_teacher.meta:get_string("chat_log"))
                local direct_msg = minetest.deserialize(mc_teacher.meta:get_string("dm_log"))
                local server_msg = minetest.deserialize(mc_teacher.meta:get_string("server_log"))
                local indexed_chat_players = {}
                local add_server = false

                for uname,_ in pairs(chat_msg or {}) do
                    if not mc_core.tableHas(indexed_chat_players, uname) then
                        table.insert(indexed_chat_players, uname)
                    end
                end
                for uname,_ in pairs(direct_msg or {}) do
                    if not mc_core.tableHas(indexed_chat_players, uname) then
                        table.insert(indexed_chat_players, uname)
                    end
                end
                for uname, msg_list in pairs(server_msg or {}) do
                    if has_server_privs then
                        if not mc_core.tableHas(indexed_chat_players, uname) then
                            table.insert(indexed_chat_players, uname)
                        end
                    else
                        local add_player = false
                        for _,msg_table in pairs(msg_list) do
                            if msg_table.recipient ~= mc_teacher.M.RECIP.ADMIN then
                                if not msg_table.anonymous then
                                    add_player = true
                                else
                                    add_server = true
                                end
                            end
                            if add_player and add_server then
                                break
                            end
                        end
                        if not mc_core.tableHas(indexed_chat_players, uname) and add_player then
                            table.insert(indexed_chat_players, uname)
                        end
                    end
                end

                if add_server then
                    table.insert(indexed_chat_players, mc_core.SERVER_USER)
                    local server_messages = {}
                    for _, msg_list in pairs(server_msg or {}) do
                        for _,msg_table in pairs(msg_list) do
                            if msg_table.anonymous and msg_table.recipient ~= mc_teacher.M.RECIP.ADMIN then
                                table.insert(server_messages, msg_table)
                            end
                        end
                    end
                    server_msg[mc_core.SERVER_USER] = server_messages
                end
                context.indexed_chat_players = indexed_chat_players

                if #indexed_chat_players > 0 then
                    if not context.player_chat_index or not indexed_chat_players[context.player_chat_index] then
                        context.player_chat_index = 1
                    end
                    local selected = indexed_chat_players[context.player_chat_index]
                    local stamps = {}
                    local stamp_to_key = {}

                    if chat_msg and chat_msg[selected] then
                        for i, msg_table in ipairs(chat_msg[selected]) do
                            table.insert(stamps, msg_table.timestamp)
                            stamp_to_key[msg_table.timestamp] = "chat:"..i
                        end
                    end
                    if direct_msg and direct_msg[selected] then
                        for i, msg_table in ipairs(direct_msg[selected]) do
                            table.insert(stamps, msg_table.timestamp)
                            stamp_to_key[msg_table.timestamp] = "dm:"..i
                        end
                    end
                    if server_msg and server_msg[selected] then
                        for i, msg_table in ipairs(server_msg[selected]) do
                            if has_server_privs or (msg_table.recipient ~= mc_teacher.M.RECIP.ADMIN and msg_table.anonymous == (selected == mc_core.SERVER_USER)) then
                                table.insert(stamps, msg_table.timestamp)
                                stamp_to_key[msg_table.timestamp] = "serv:"..i
                            end
                        end
                    end
                    table.sort(stamps)

                    local player_log = {}
                    context.log_i_to_key = {}
                    local chat_col = "#CCFFFF"
                    local dm_col = "#FFFFCC"
                    local serv_col = "#FFCCFF"

                    -- build main message list
                    for i, stamp in ipairs(stamps) do
                        local key = stamp_to_key[stamp] or "null:0"
                        local split_key = mc_core.split(key, ":")
                        local index = tonumber(split_key[2] or "0")
                        if split_key[1] == "chat" and index ~= 0 then
                            local msg_table = chat_msg[selected][index]
                            table.insert(player_log, chat_col..minetest.formspec_escape(table.concat({"[", stamp, "] ", msg_table.message})))
                        elseif split_key[1] == "dm" and index ~= 0 then
                            local msg_table = direct_msg[selected][index]
                            table.insert(player_log, dm_col..minetest.formspec_escape(table.concat({"[", stamp, "] DM to ", msg_table.recipient, ": ", msg_table.message})))
                        elseif split_key[1] == "serv" and index ~= 0 then
                            local msg_table = server_msg[selected][index]
                            table.insert(player_log, serv_col..minetest.formspec_escape(table.concat({"[", stamp, "] ", mc_core.SERVER_USER, " to ", msg_table.recipient, ": ", msg_table.message})))
                        end
                        table.insert(context.log_i_to_key, key)
                    end

                    if not context.message_chat_index or not context.log_i_to_key[context.message_chat_index] then
                        context.message_chat_index = 1
                    end
                    local selected_key = context.log_i_to_key[context.message_chat_index]
                    local sel_split_key = mc_core.split(selected_key, ":")
                    local sel_index = tonumber(sel_split_key[2] or "0")
                    local display_message = {}

                    if sel_split_key[1] == "chat" and chat_msg[selected][sel_index] then
                        display_message.header = "Global chat message"
                        display_message.message = chat_msg[selected][sel_index].message
                    elseif sel_split_key[1] == "dm" and direct_msg[selected][sel_index] then
                        display_message.header = "Direct message to "..direct_msg[selected][sel_index].recipient
                        display_message.message = direct_msg[selected][sel_index].message
                    elseif sel_split_key[1] == "serv" and server_msg[selected][sel_index] then
                        display_message.header = "Server message to "..server_msg[selected][sel_index].recipient
                        display_message.message = server_msg[selected][sel_index].message
                    end

                    table.insert(fs, table.concat({
                        "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Message Logs]",
                        "textlist[", spacer, ",1.4;", panel_width - 2*spacer, ",5.5;mod_log_players;", table.concat(indexed_chat_players, ","), ";", context.player_chat_index, ";false]",
                    }))

                    if selected == mc_core.SERVER_USER then
                        table.insert(fs, table.concat({
                            "textarea[", text_spacer, ",7.1;", panel_width - 2*text_spacer, ",1;;;Who is ", mc_core.SERVER_USER, "?]",
                            "style_type[textarea;font=mono]",
                            "textarea[", text_spacer, ",7.5;", panel_width - 2*text_spacer, ",2.3;;;", mc_core.SERVER_USER, " is not a player. It is a reserved name used to represent something done by the Minetest Classroom server or a server administrator.\nThe messages logged here are server messages sent by server administrators.]",
                            "style_type[textarea;font=mono,bold]",
                        }))
                    elseif not minetest.get_player_by_name(selected) then
                        table.insert(fs, table.concat({
                            "style[blocked;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",
                            "button[", spacer, ",7;3.5,0.8;blocked;Mute player]",
                            "button[", spacer + 3.6, ",7;3.5,0.8;mod_clearlog;Delete log]",
                            "textarea[", text_spacer, ",8;", panel_width - 2*text_spacer, ",1;;;Message ", selected or "player", "]",
                            "style_type[textarea;font=mono]",
                            "textarea[", spacer, ",8.4;", panel_width - 2*spacer, ",1.4;;;This player is currently not online and thus can not be messaged.]",
                            "style_type[textarea;font=mono,bold]",
                        }))
                    else
                        local sel_obj = minetest.get_player_by_name(selected)
                        local sel_meta = sel_obj:get_meta()
                        local sel_privs = minetest.deserialize(sel_meta:get_string("universalPrivs")) or {}
                        table.insert(fs, table.concat({
                            "button[", spacer, ",7;3.5,0.8;", sel_privs and sel_privs.shout == false and "mod_unmute;Unmute player" or "mod_mute;Mute player", "]",
                            "button[", spacer + 3.6, ",7;3.5,0.8;mod_clearlog;Delete log]",
                            "textarea[", text_spacer, ",8;", panel_width - 2*text_spacer, ",1;;;Message ", selected or "player", "]",
                            "style_type[textarea;font=mono]",
                            "textarea[", spacer, ",8.4;", panel_width - 2*spacer - 0.8, ",1.4;mod_message;;", context.mod_message or "", "]",
                            "style_type[textarea;font=mono,bold]",
                            "button[", panel_width - spacer - 0.8, ",8.4;0.8,1.4;mod_send_message;Send]",
                        }))
                    end

                    table.insert(fs, table.concat({
                        "textarea[", panel_width + text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Sent Messages]",
                        "textlist[", panel_width + spacer, ",1.4;", panel_width - 2*spacer, ",6.4;mod_log_messages;", table.concat(player_log, ","), ";", context.message_chat_index, ";false]",
                        "textarea[", panel_width + text_spacer, ",8;", panel_width - 2*text_spacer, ",1;;;", display_message and display_message.header or "Unknown", "]",
                        "style_type[textarea;font=mono]",
                        "textarea[", panel_width + text_spacer, ",8.4;", panel_width - 2*text_spacer, ",1.4;;;", display_message and display_message.message or "", "]",
                        "tooltip[mod_clearlog;Removes all messages sent by the selected player from the log;#404040;#ffffff]",
                    }))
                else
                    -- fallback formspec
                    table.insert(fs, table.concat({
                        "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;No messages logged!]",
                        "style_type[textarea;font=mono]",
                        "textarea[", text_spacer, ",1.5;", panel_width - 2*text_spacer, ",8.3;;;When players send chat messages or direct messages to other players, they will be logged here!]",
                    }))
                end

                return fs
            end,
            [mc_teacher.TABS.REPORTS] = function()
                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Reports</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Report Info</b></center></style>]",
                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "style_type[button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    "style[blocked;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",
                }

                context.report_i_to_idx = {}
                local report_log = minetest.deserialize(mc_teacher.meta:get_string("report_log")) or {}
                local report_strings = {}
                local report_idx_to_key = {}

                for idx, report in pairs(report_log) do
                    local report_string = minetest.formspec_escape("["..report.timestamp.."] "..report.type.." by "..report.player)
                    table.insert(report_strings, report_string)
                    report_idx_to_key[report_string] = idx
                end
                table.sort(report_strings)
                for i,string in ipairs(report_strings) do
                    context.report_i_to_idx[i] = report_idx_to_key[string]
                end

                context.selected_report = context.selected_report or 1
                if context.selected_report > #report_strings then
                    context.selected_report = math.max(#report_strings, 1)
                end
                local selected = report_log[context.report_i_to_idx[context.selected_report]]

                table.insert(fs, table.concat({
                    "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Report Log]",
                    "textlist[", spacer, ",1.4;", panel_width - 2*spacer, ",7.5;report_log;", table.concat(report_strings, ","), ";", context.selected_report, ";false]",
                    "button[", spacer, ",9;3.5,0.8;", selected and "report_delete" or "blocked", ";Delete report]",
                    "button[", spacer + 3.6, ",9;3.5,0.8;", selected and "report_clearlog" or "blocked", ";Clear report log]",
                }))

                if selected then
                    table.insert(fs, table.concat({
                        "textarea[", panel_width + text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;", string.upper(selected.type or "Other"), "]",
                        "textarea[", panel_width + text_spacer, ",8;7.2,1;;;Message ", selected.player or "reporter", "]",
                        "style_type[textarea;font=mono]",
                        "textarea[", panel_width + text_spacer, ",1.4;", panel_width - 2*text_spacer, ",6.5;;;",
                        selected.message or "", "\n\n", "Reported on ", selected.timestamp or "an unknown date", " by ", selected.player or "an unknown player", "\n",
                        "Realm ID ", selected.realm or "unknown", ", at ", selected.pos and "(X="..selected.pos.x..", Y="..selected.pos.y..", Z="..selected.pos.z..")" or "an unknown position", "]",
                        "textarea[", panel_width + spacer, ",8.4;", panel_width - 2*spacer - 0.8, ",1.4;report_message;;", context.report_message or "", "]",
                        "style_type[textarea;font=mono,bold]",
                        "button[", controller_width - spacer - 0.8, ",8.4;0.8,1.4;report_send_message;Send]",
                    }))
                else
                    table.insert(fs, table.concat({
                        "textarea[", panel_width + text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;No reports found!]",
                        "style_type[textarea;font=mono]",
                        "textarea[", panel_width + text_spacer, ",1.4;", panel_width - 2*text_spacer, ",6.5;;;When a player submits a report, it will appear here!]",
                    }))
                end

                return fs
            end,
            [mc_teacher.TABS.HELP] = function()
                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Help</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Getting Started</b></center></style>]",
                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Game controls]",
                    "style_type[textarea;font=mono]",
                    "textarea[", text_spacer, ",1.5;", panel_width - 2*text_spacer, ",8.3;;;", mc_core.get_controls_info(true), "]",

                    "style_type[textarea;font=mono,bold]",
                    "textarea[", panel_width + text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;More help coming soon!]",
                }

                return fs
            end,
            [mc_teacher.TABS.SERVER] = function()
                -- TODO: Implement ban manager
                local whitelist_state = minetest.deserialize(networking.storage:get_string("enabled"))

                local fs = {
                    "image[0,0;", controller_width, ",0.5;mc_pixel.png^[multiply:#737373]",
                    "image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]",
                    "tooltip[exit;Exit;#404040;#ffffff]",
                    "hypertext[", text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Server Management</b></center></style>]",
                    "hypertext[", panel_width + text_spacer, ",0.1;", panel_width - 2*text_spacer, ",1;;<style font=mono><center><b>Server Whitelist</b></center></style>]",
                    "style_type[textarea;font=mono,bold;textcolor=#000000]",
                    "style_type[button;border=false;font=mono,bold;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.default, "]",
                    "style[server_ban_manager;bgimg=mc_pixel.png^[multiply:", mc_core.col.b.blocked, "]",

                    "textarea[", text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Global Messenger]",
                    "style_type[textarea,field;font=mono]",
                    "textarea[", spacer, ",1.4;", panel_width - 2*spacer, ",2.1;server_message;;", context.server_message or "", "]",
                    "style_type[textarea;font=mono,bold]",
                    "textarea[", text_spacer, ",3.6;", panel_width - 2*text_spacer, ",1;;;Send as:]",
                    "dropdown[", spacer, ",4.0;", panel_width - 2*spacer, ",0.8;server_message_type;General server message,Server message from yourself,Chat message from yourself;", context.server_message_type or mc_teacher.M.MODE.SERVER_ANON, ";true]",
                    "textarea[", text_spacer, ",4.9;", panel_width - 2*text_spacer, ",1;;;Send to:]",
                    "button[", spacer, ",5.3;1.7,0.8;server_send_teachers;Teachers]",
                    "button[", spacer + 1.8, ",5.3;1.7,0.8;server_send_students;Students]",
                    "button[", spacer + 3.6, ",5.3;1.7,0.8;server_send_admins;Admins]",
                    "button[", spacer + 5.4, ",5.3;1.7,0.8;server_send_all;Everyone]",
                    "textarea[", text_spacer, ",6.3;", panel_width - 2*text_spacer, ",1;;;Schedule Server Shutdown]",
                }

                local time_options = {}
                for t, t_table in pairs(mc_teacher.T_INDEX) do
                    time_options[t_table.i] = t
                end

                local ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
                local ip_whitelist = {}
                for ipv4,_ in pairs(ipv4_whitelist) do
                    table.insert(ip_whitelist, ipv4)
                end
                table.sort(ip_whitelist, networking.ipv4_compare)

                table.insert(fs, table.concat({
                    "dropdown[", spacer, ",6.7;", panel_width - 2*spacer, ",0.8;server_shutdown_timer;", table.concat(time_options, ","), ";", context.time_index or 1, ";false]",
                    "button[", spacer, ",7.6;3.5,0.8;server_shutdown_", mc_teacher.restart_scheduled.timer and "cancel" or "schedule", ";", mc_teacher.restart_scheduled.timer and "Cancel shutdown" or "Schedule", "]",
                    "button[", spacer + 3.6, ",7.6;3.5,0.8;server_shutdown_now;Shutdown now]",
                    "textarea[", text_spacer, ",8.6;", panel_width - 2*text_spacer, ",1;;;Misc. actions]",
                    "button[", spacer, ",9;3.5,0.8;server_ban_manager;Banned players]",
                    "button[", spacer + 3.6, ",9;3.5,0.8;server_edit_rules;Server rules]",

                    "textarea[", panel_width + text_spacer, ",1;", panel_width - 2*text_spacer, ",1;;;Whitelisted IPv4 Addresses]",
                    "textlist[", panel_width + spacer, ",1.4;", panel_width - 2*spacer, ",4.9;server_whitelist;", table.concat(ip_whitelist, ","), ";", context.selected_ip_range or 1, ";false]",
                    "button[", panel_width + spacer, ",6.4;3.5,0.8;server_whitelist_toggle;", whitelist_state and "DISABLE" or "ENABLE", " whitelist]",
                    "button[", panel_width + spacer + 3.6, ",6.4;3.5,0.8;server_whitelist_remove;Delete range]",
                    "textarea[", panel_width + text_spacer, ",7.4;", panel_width - 2*text_spacer, ",1;;;Modify Whitelist]",
                    "style_type[textarea;font_size=*0.85]",
                    "textarea[", panel_width + text_spacer, ",8.6;3.6,0.8;;;Start IPv4]",
                    "textarea[", panel_width + text_spacer + 3.6, ",8.6;3.6,0.8;;;End IPv4]",
                    "field[", panel_width + spacer, ",7.8;3.5,0.8;server_ip_start;;", context.start_ip or "0.0.0.0", "]",
                    "field[", panel_width + spacer + 3.6, ",7.8;3.5,0.8;server_ip_end;;", context.end_ip or "", "]",
                    "field_close_on_enter[server_ip_start;false]",
                    "field_close_on_enter[server_ip_end;false]",
                    "button[", panel_width + spacer, ",9;3.5,0.8;server_ip_add;Add range]",
                    "button[", panel_width + spacer + 3.6, ",9;3.5,0.8;server_ip_remove;Remove range]",

                    "tooltip[server_message;Type your message here!;#404040;#ffffff]",
                    "tooltip[server_ban_manager;View and manage banned players;#404040;#ffffff]",
                    "tooltip[server_edit_rules;Edit server rules;#404040;#ffffff]",
                    "tooltip[server_ip_start;First IPv4 address in the desired range;#404040;#ffffff]",
                    "tooltip[server_ip_end;Last IPv4 address in the desired range (optional);#404040;#ffffff]",
                    "tooltip[server_whitelist_remove;Removes the selected IP range from the whitelist;#404040;#ffffff]",
                    "tooltip[server_ip_add;Adds the typed range of IPs to the whitelist;#404040;#ffffff]",
                    "tooltip[server_ip_remove;Removes the typed range of IPs from the whitelist;#404040;#ffffff]",
                    "tooltip[server_whitelist_toggle;Whitelist is currently ", whitelist_state and "ENABLED" or "DISABLED", ";#404040;#ffffff]",
                }))

                return fs
            end,
        }

        -- Remove unauthorized tabs
        if not has_server_privs then
            tab_map[mc_teacher.TABS.SERVER] = nil
        end

        local bookmarked_tab = pmeta:get_string("default_teacher_tab")
        if not tab_map[bookmarked_tab] then
            bookmarked_tab = nil
            pmeta:set_string("default_teacher_tab", nil)
        end
        local selected_tab = (tab_map[tab] and tab) or (tab_map[context.tab] and context.tab) or bookmarked_tab or "1"
        context.tab = selected_tab
        mc_teacher.check_selected_priv_mode(context)

        local teacher_formtable = {
            "formspec_version[6]",
            "size[", controller_width, ",", controller_height, "]",
            mc_core.draw_book_fs(controller_width, controller_height, {bg = "#404040", shadow = "#303030", binding = "#333333", divider = "#969696"}),
            "style[tabheader;noclip=true]",
            "tabheader[0,-0.25;", controller_width, ",0.55;record_nav;Overview,Classrooms,Map,Players,Moderation,Reports,Help",
            has_server_privs and ",Server" or "", ";", selected_tab, ";true;false]",
            table.concat(tab_map[selected_tab](), "")
        }

        if bookmarked_tab == selected_tab then
            table.insert(teacher_formtable, table.concat({
                "style_type[image;noclip=true]",
                "image[", controller_width - 0.6, ",-0.25;0.5,0.7;mc_teacher_bookmark_filled.png]",
                "tooltip[", controller_width - 0.6, ",-0.25;0.5,0.8;This tab is currently bookmarked;#404040;#ffffff]",
            }))
        else
            table.insert(teacher_formtable, table.concat({
                "image_button[", controller_width - 0.6, ",-0.25;0.5,0.5;mc_teacher_bookmark_hollow.png^[colorize:#FFFFFF:127;default_tab;;true;false]",
                "tooltip[default_tab;Bookmark this tab?;#404040;#ffffff]",
            }))
        end

        minetest.show_formspec(pname, "mc_teacher:controller_fs", table.concat(teacher_formtable, ""))
        return true
    end
end

--[[
NEW FORMSPEC CLEAN COPIES

TAB GROUPING:
[1] OVERVIEW + RULES
[2] CLASSROOM MANAGEMENT
[3] MAP + COORDINATES
[4] PLAYER MANAGEMENT
[5] MODERATION
[6] HELP
[7] REPORT LOG
[8] SERVER MANAGEMENT (extra)

OVERVIEW + RULES:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.2,1;;;Overview]
textarea[8.85,0.1;7.2,1;;;Dashboard]
textarea[0.55,1;7.2,1;;;Welcome to Minetest Classroom!]
textarea[0.55,1.5;7.2,2.8;;;This is the Teacher Controller\, your tool for managing classrooms\, player privileges\, and server settings. You cannot drop or delete this tool\, so you will never lose it\, but you can move it out of your hotbar and into your inventory or the toolbox.]
textarea[0.55,4.4;7.2,1;;;Server Rules]
textarea[0.55,4.9;7.2,4;;;These are the server rules!]
button[0.6,9;7.1,0.8;modifyrules;Edit Server Rules]
image_button[8.9,1;1.7,1.6;mc_teacher_classrooms.png;classrooms;;false;false]
image_button[8.9,2.8;1.7,1.6;mc_teacher_map.png;map;;false;false]
image_button[8.9,4.6;1.7,1.6;mc_teacher_players.png;players;;false;false]
image_button[8.9,6.4;1.7,1.6;mc_teacher_isometric.png;help;;false;false]
image_button[8.9,8.2;1.7,1.6;mc_teacher_isometric.png;help;;false;false]
textarea[10.7,1.3;5.35,1.6;;;ClassroomsnFind classrooms or players]
textarea[10.7,3.1;5.35,1.6;;;MapnRecord and share locations]
textarea[10.7,4.9;5.35,1.6;;;PlayersnManage player privileges]
textarea[10.7,6.7;5.35,1.6;;;ModerationnView player chat logs]
textarea[10.7,8.5;5.35,1.6;;;ReportsnView player reports]
image[16,-0.25;0.5,0.8;mc_teacher_bookmark.png]

CLASSROOMS:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.2,1;;;Classrooms]
textarea[8.85,0.1;7.2,1;;;Build a Classroom]
textarea[0.55,1;7.2,1;;;Available Classrooms]
textlist[0.6,1.4;7.1,7.5;classroomlist;;1;false]
button[0.6,9;2.3,0.8;teleportrealm;Teleport]
button[3,9;2.3,0.8;editrealm;Edit]
button[5.4,9;2.3,0.8;deleterealm;Delete]
textarea[8.85,1;7.2,1;;;Name]
field[8.9,1.4;7.1,0.8;realmname;;]
textarea[8.85,2.3;3.6,1;;;Type]
dropdown[8.9,2.7;3.5,0.8;realmcategory;Default,Spawn,Classroom,Instanced;1;true]
textarea[12.45,2.3;3.6,1;;;Generation]
dropdown[12.5,2.7;3.5,0.8;mode;Empty World,Schematic,Digital Twin;1;true]
textarea[8.85,3.6;7.2,1;;;OPTIONS]
box[8.9,4;7.1,0.8;#808080]
textarea[8.85,4.9;7.2,1;;;Default Privileges]
textarea[10.15,5.7;2.3,1;;;interact]
textarea[10.15,6.1;2.3,1;;;shout]
textarea[10.15,6.5;2.3,1;;;fast]
textarea[13.75,5.7;2.3,1;;;fly]
textarea[13.75,6.1;2.3,1;;;noclip]
textarea[13.75,6.5;2.3,1;;;give]
image[8.9,5.3;0.4,0.4;mc_teacher_allowpriv.png]
image[9.3,5.3;0.4,0.4;mc_teacher_ignorepriv.png]
image[9.7,5.3;0.4,0.4;mc_teacher_denypriv.png]
image[12.5,5.3;0.4,0.4;mc_teacher_allowpriv.png]
image[12.9,5.3;0.4,0.4;mc_teacher_ignorepriv.png]
image[13.3,5.3;0.4,0.4;mc_teacher_denypriv.png]
checkbox[8.9,5.9;allowpriv_interact;;true]
checkbox[8.9,6.3;allowpriv_shout;;true]
checkbox[8.9,6.7;allowpriv_fast;;true]
checkbox[9.3,5.9;ignorepriv_interact;;false]
checkbox[9.3,6.3;ignorepriv_shout;;false]
checkbox[9.3,6.7;ignorepriv_fast;;false]
checkbox[9.7,5.9;denypriv_interact;;false]
checkbox[9.7,6.3;denypriv_shout;;false]
checkbox[9.7,6.7;denypriv_fast;;false]
checkbox[12.5,5.9;allowpriv_fly;;false]
checkbox[12.5,6.3;allowpriv_noclip;;false]
checkbox[12.5,6.7;allowpriv_give;;false]
checkbox[12.9,5.9;ignorepriv_fly;;true]
checkbox[12.9,6.3;ignorepriv_noclip;;true]
checkbox[12.9,6.7;ignorepriv_give;;true]
checkbox[13.3,5.9;denypriv_fly;;false]
checkbox[13.3,6.3;denypriv_noclip;;false]
checkbox[13.3,6.7;denypriv_give;;false]
textarea[8.85,7;7.2,1;;;Background Music]
dropdown[8.9,7.4;7.1,0.8;bgmusic;;1;true]
textarea[8.85,8.3;7.2,1;;;Skybox]
dropdown[8.9,8.7;7.1,0.8;;;1;true]
button[8.9,9;7.1,0.8;requestrealm;Generate Classroom]

MAP + COORDINATES:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.1,1;;;Map]
textarea[8.85,0.1;7.1,1;;;Coordinates]
textarea[0.55,1;7.1,1;;;Surrounding Area]
box[0.6,1.4;7.1,7.1;#000000]
box[0.625,1.425;7.05,7.05;#808080]
image[4,4.8;0.3,0.3;]
textarea[0.55,8.6;7.1,1;;;Coordinate and Elevation Display]
button[0.6,9;1.7,0.8;utmcoords;UTM]
button[2.4,9;1.7,0.8;latloncoords;Lat/Long]
button[4.2,9;1.7,0.8;classroomcoords;Local]
button[6,9;1.7,0.8;coordsoff;Off]
textarea[8.85,1;7.1,1;;;Saved Coordinates]
textlist[8.9,1.4;7.1,4.4;coordlist;;8;false]
textarea[8.85,8.5;7.1,1;;;Save current coordinates]
image_button[15.1,8.9;0.9,0.9;blank.png;;Save;false;true]
textarea[8.9,8.9;6.2,0.9;note;;]
textarea[8.85,7.2;7.2,1.1;;;(coordinate name) (coords) (realm)]
image_button[8.9,5.9;1.1,1.1;blank.png;go;TP;false;true]
image_button[10.1,5.9;1.1,1.1;blank.png;go_all;TP_A;false;true]
image_button[12.5,5.9;1.1,1.1;blank.png;mark;MK;false;true]
image_button[11.3,5.9;1.1,1.1;blank.png;share;SH;false;true]
image_button[13.7,5.9;1.1,1.1;blank.png;delete;DL;false;true]
image_button[14.9,5.9;1.1,1.1;blank.png;clear;DL_A;false;true]

PLAYERS:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.2,1;;;Online Players]
textarea[8.85,0.1;7.2,1;;;Manage Players]
textarea[0.55,1;6.7,1;;;Students]
textlist[0.6,1.4;7.1,7.5;student_list;;1;false]
button[7.25,0.95;0.45,0.45;p_group_new;+]
button[0.6,9;3.5,0.8;p_group_edit;Edit group]
button[4.2,9;3.5,0.8;p_group_delete;Delete group]
image[4.25,1.45;0.4,0.4;]
image[4.75,1.45;0.4,0.4;]
image[5.25,1.45;0.4,0.4;]
image[5.75,1.45;0.4,0.4;]
image[6.25,1.45;0.4,0.4;]
image[6.75,1.45;0.4,0.4;]
image[7.25,1.45;0.4,0.4;]
textarea[8.85,1;7.2,1;;;Action Mode]
button[8.9,1.4;2.3,0.8;;Selected]
button[11.3,1.4;2.3,0.8;;Group]
button[13.7,1.4;2.3,0.8;;All]
textarea[8.85,2.3;7.2,1;;;Privileges in this Classroom]
textarea[10.15,3.1;2.3,1;;;interact]
textarea[10.15,3.5;1.8,1;;;shout]
textarea[10.15,3.9;1.8,1;;;fast]
textarea[13.75,3.1;1.8,1;;;fly]
textarea[13.75,3.5;1.8,1;;;noclip]
textarea[13.75,3.9;1.8,1;;;give]
image[8.9,2.7;0.4,0.4;mc_teacher_allowpriv.png]
image[9.3,2.7;0.4,0.4;mc_teacher_ignorepriv.png]
image[9.7,2.7;0.4,0.4;mc_teacher_denypriv.png]
image[12.5,2.7;0.4,0.4;mc_teacher_allowpriv.png]
image[12.9,2.7;0.4,0.4;mc_teacher_ignorepriv.png]
image[13.3,2.7;0.4,0.4;mc_teacher_denypriv.png]
checkbox[8.9,3.3;allowpriv_interact;;false]
checkbox[8.9,3.7;allowpriv_shout;;false]
checkbox[8.9,4.1;allowpriv_fast;;false]
checkbox[9.3,3.3;ignorepriv_interact;;true]
checkbox[9.3,3.7;ignorepriv_shout;;true]
checkbox[9.3,4.1;ignorepriv_fast;;true]
checkbox[9.7,3.3;denypriv_interact;;false]
checkbox[9.7,3.7;denypriv_shout;;false]
checkbox[9.7,4.1;denypriv_fast;;false]
checkbox[12.5,3.3;allowpriv_fly;;false]
checkbox[12.5,3.7;allowpriv_noclip;;false]
checkbox[12.5,4.1;allowpriv_give;;false]
checkbox[12.9,3.3;ignorepriv_fly;;true]
checkbox[12.9,3.7;ignorepriv_noclip;;true]
checkbox[12.9,4.1;ignorepriv_give;;true]
checkbox[13.3,3.3;denypriv_fly;;false]
checkbox[13.3,3.7;denypriv_noclip;;false]
checkbox[13.3,4.1;denypriv_give;;false]
button[8.9,4.4;3.5,0.8;p_priv_update;Update privs]
button[12.5,4.4;3.5,0.8;p_priv_reset;Reset privs]
textarea[8.85,5.3;7.2,1;;;Actions]
button[8.9,5.7;2.3,0.8;p_teleport;Teleport]
button[11.3,5.7;2.3,0.8;p_bring;Bring]
button[13.7,5.7;2.3,0.8;p_audience;Audience]
button[8.9,6.6;2.3,0.8;p_mute;Mute]
button[11.3,6.6;2.3,0.8;p_deactivate;Deactivate]
button[13.7,6.6;2.3,0.8;p_freeze;Freeze]
button[8.9,7.5;2.3,0.8;p_timeout;Timeout]
button[11.3,7.5;2.3,0.8;p_kick;Kick]
button[13.7,7.5;2.3,0.8;p_ban;Ban]
textarea[8.9,8.4;7.2,1;;;Server Role]
box[12.5,8.8;3.5,1;#FFCC00]
box[8.9,8.8;3.5,1;#00FF00]
button[9,8.9;1.6,0.8;p_role_none;None]
button[10.7,8.9;1.6,0.8;p_role_student;Student]
button[12.6,8.9;1.6,0.8;p_role_teacher;Teacher]
button[14.3,8.9;1.6,0.8;p_role_admin;Admin]

MODERATION:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.1,1;;;Moderation]
textarea[8.85,0.1;7.1,1;;;Message Log]
textarea[0.55,1;7.2,1;;;Message Logs]
textlist[0.6,1.4;7.1,5.5;mod_log_players;;1;false]
button[0.6,7;3.5,0.8;mod_mute;Mute player]
button[4.2,7;3.5,0.8;mod_clearlog;Clear player's log]
textarea[0.55,8;7.2,1;;;Message player]
textarea[0.6,8.4;6.3,1.4;mod_message;;]
button[6.9,8.4;0.8,1.4;mod_send_message;Send]
textarea[8.85,1;7.2,1;;;Sent Messages]
textlist[8.9,1.4;7.1,6.4;mod_log_messages;;1;false]
textarea[8.85,8;7.2,1;;;(message type)]
textarea[8.85,8.4;7.2,1.4;;;add message text here!]

REPORTS:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.1,1;;;Reports]
textarea[8.85,0.1;7.1,1;;;Report Info]
textarea[0.55,1;7.2,1;;;Report Log]
textlist[0.6,1.4;7.1,7.5;report_log;;1;false]
button[0.6,9;3.5,0.8;report_delete;Delete report]
button[4.2,9;3.5,0.8;report_clearlog;Clear report log]
textarea[8.85,1;7.2,1;;;(TYPE)]
textarea[8.85,1.4;7.2,6.5;;;Report info]
textarea[8.85,8;7.2,1;;;Message player]
textarea[8.9,8.4;6.3,1.4;report_message;;]
button[15.2,8.4;0.8,1.4;report_send_message;Send]

HELP:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.1,1;;;Help]
textarea[8.85,0.1;7.1,1;;;Getting Started]
textarea[0.55,1;7.2,1;;;Controls]
textarea[0.55,1.5;7.2,8.3;;;Add controls here!]

SERVER:
formspec_version[6]
size[16.6,10.4]
box[0,0;16.6,0.5;#737373]
box[8.275,0;0.05,10.4;#000000]
image_button_exit[0.2,0.05;0.4,0.4;mc_x.png;exit;;false;false]
textarea[0.55,0.1;7.1,1;;;Server Management]
textarea[8.85,0.1;7.1,1;;;Server Whitelist]
textarea[0.55,1;7.2,1;;;Global Messenger]
textarea[0.6,1.4;7.1,2.1;server_message;;]
textarea[0.55,3.6;7.2,1;;;Send as:]
dropdown[0.6,4;7.1,0.8;server_message_type;Anonymous server message,Server message from yourself,Chat message from yourself;1;true]
textarea[0.55,4.9;7.2,1;;;Send to:]
button[0.6,5.3;1.7,0.8;server_send_teachers;Teachers]
button[2.4,5.3;1.7,0.8;server_send_students;Students]
button[4.2,5.3;1.7,0.8;server_send_admins;Admins]
button[6,5.3;1.7,0.8;server_send_all;Everyone]
textarea[0.55,6.3;7.2,1;;;Schedule Server Shutdown]
dropdown[0.6,6.7;7.1,0.8;server_shutdown_timer;;1;false]
button[0.6,7.6;3.5,0.8;server_shutdown_schedule;Schedule]
button[4.2,7.6;3.5,0.8;server_shutdown_now;Shutdown now]
textarea[0.55,8.6;7.2,1;;;Misc. actions]
button[0.6,9;3.5,0.8;server_ban_manager;Banned players]
button[4.2,9;3.5,0.8;server_edit_rules;Server rules]
textarea[8.85,1;7.2,1;;;Whitelisted IPv4 Addresses]
textlist[8.9,1.4;7.1,4.9;server_whitelist;;1;false]
button[8.9,6.4;3.5,0.8;server_whitelist_toggle;ENABLE whitelist]
button[12.5,6.4;3.5,0.8;server_whitelist_remove;Delete range]
textarea[8.85,7.4;7.2,1;;;Modify Whitelist]
textarea[8.85,8.6;3.6,1;;;Start IPv4]
textarea[12.45,8.6;3.6,1;;;End IPv4 (optional)]
field[8.9,7.8;3.5,0.8;server_ip_start;;0.0.0.0]
field[12.5,7.8;3.5,0.8;server_ip_end;;]
button[8.9,9;3.5,0.8;server_ip_add;Add range]
button[12.5,9;3.5,0.8;sever_ip_remove;Remove range]
]]
