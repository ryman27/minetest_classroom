
-- Global variables
minetest_classroom.reports = minetest.get_mod_storage()
minetest_classroom.mc_students = {teachers = {}}
mc_student = {path = minetest.get_modpath("mc_student")}

-- Local variables
local tool_name = "mc_student:notebook"
local priv_table = {interact = true}

minetest.register_on_joinplayer(function(player)
	if minetest.check_player_privs(player, { teacher = true }) then
		minetest_classroom.mc_students.teachers[player:get_player_name()] = true
	end
end)

minetest.register_on_leaveplayer(function(player)
	minetest_classroom.mc_students.teachers[player:get_player_name()] = nil
end)

------------------------------------
--- FORMSPEC DEFINITIONS/HELPERS ---
------------------------------------

-------------------------
--- MAIN STUDENT MENU ---
local mc_student_menu = {
	"formspec_version[5]",
	"size[10,9]",
	"label[3.1,0.7;What do you want to do?]",
	"button[1,1.6;3.8,1.3;spawn;Go Home]",
	"button[5.2,1.6;3.8,1.3;classrooms;Join Classroom]",
	"button[1,3.3;3.8,1.3;coordinates;My Coordinates]",
	"button[5.2,3.3;3.8,1.3;marker;Place a Marker]",
	"button[1,5;3.8,1.3;taskstudent;View Tasks]",
	"button[5.2,5;3.8,1.3;report;Report]",
	"button_exit[3.1,6.7;3.8,1.3;exit;Exit]"
}

local function show_student_menu(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		minetest.show_formspec(player:get_player_name(), "mc_student:menu", table.concat(mc_student_menu,""))
	end
end
-----------------------------


------------------
--- CLASSROOMS ---
local mc_student_classrooms = {
	"formspec_version[6]",
	"size[6.5,7.5]",
	"label[2.5,0.5;Classrooms]",
	"pwdfield[0.6,5.8;3,0.5;accesscode;Enter Access Code]",
	"button[5.3,6.7;1,0.6;join;Join]",
	"button[0.2,6.7;1,0.6;back;Back]",
	"button[4,5.7;2,0.6;register;Register]",
	"textlist[0.6,0.9;5.4,4.3;realms;;1]"
}

local classroomRealms = {}
local selectedClassroom = 1

local function show_classrooms(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local textlist = "textlist[0.6,0.9;5.4,4.3;realms;;1]"
		local is_first = true

		for i,realm in ipairs(Realm.realmDict) do
			if realm:getCategory().joinable(realm,player) then
				classroomRealms[i] = realm

				if not is_first then
					textlist = textlist:sub(1, -4) .. "," .. realm.Name .. ";1]"
				else
					textlist = textlist:sub(1, -4) .. realm.Name .. ";1]"
					is_first = false
				end	
			end
		end

		mc_student_classrooms[#mc_student_classrooms] = textlist
		minetest.show_formspec(player:get_player_name(), "mc_student:classrooms", table.concat(mc_student_classrooms,""))
	end
end

function check_access_code(submitted, codes)
	local found = false
	local loc = 1
	for _,v in pairs(codes) do
	    if v == submitted then
		    local found = true
		    return loc
	    end
	    loc = loc + 1
	end
    return found
end
----------------------


----------------------
--- REPORT ---
local mc_student_report = {
	"formspec_version[5]",
	"size[7,7]",
	"label[1.8,0.8;What are you reporting?]",
	"button[0.7,5.2;2,0.8;back;Back]",
	"button_exit[2.9,5.2;2,0.8;submit;Submit]",
	"textarea[0.7,1.5;5.6,3.1;report;; ]"
}

local function show_report(player)
	local pname = player:get_player_name()
	minetest.show_formspec(pname, "mc_student:report", table.concat(mc_student_report,""))
	return true
end
-----------------------


-----------------------
--- MARKER ---
local mc_student_marker = {
	"formspec_version[5]",
	"size[7,6.5]",
	"position[0.3,0.5]",
	"label[1.8,0.8;Add text to your marker]",
	"button[0.7,5.2;2,0.8;back;Back]",
	"button_exit[2.9,5.2;2,0.8;submit;Submit]",
	"textarea[0.7,1.5;5.6,3.1;message;; ]"
}

	local function show_marker(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:marker", table.concat(mc_student_marker,""))
		return true
	end
end
----------------------


-------------------
--- COORDINATES ---
local selectedCoord = 0

mc_student_coordinates = {
	"formspec_version[6]",
	"size[13,9.3]",
	"label[5.4,0.4;Coordinates Stored]",
	"button[9.3,7.6;3.3,0.6;record;Record]",
	"button[9.3,8.5;1.6,0.6;delete;Delete]",
	"button[11.2,8.5;1.4,0.6;go;Go]",
	"button[7.2,8.5;1.7,0.6;clear;Clear All]",
	"button[0.4,8.5;1.2,0.6;back;Back]",
	"textarea[0.4,7.6;8.5,0.6;note;Add a note describing your current location;]",
	"textlist[0.4,0.7;12.2,6.4;coordlist;;1;false]" 
}

local function show_coordinates(player)
	selectedCoord = 0

	-- Get the stored coordinates for the player
	local coordsList = {}
	local pmeta = player:get_meta()
	pdata = minetest.deserialize(pmeta:get_string("coordinates"))

	if pdata == nil then
		table.insert(coordsList, "No Coordinates Stored")
	else
		local prealms = pdata.realms
		local pcoords = pdata.coords
		local pnotes = pdata.notes

		if pcoords then
			for i in pairs(pcoords) do
				local realm = Realm.GetRealm(prealms[i])
				local pos = pcoords[i]
				local utm = realm:WorldToUTMSpace(pos)
				local latlong = realm:WorldToLatLongSpace(pos) 
				local entry = realm.Name .. " "

				if utm then
					entry = entry .. math.floor(utm.x) .. "E " .. math.floor(utm.z) .. "N " .. math.floor(utm.y) .. "Z"
				else
					entry = entry .. "x=" .. math.floor(pos.x) .. " y=" .. math.floor(pos.y) .. " z=" .. math.floor(pos.z)
				end

				if latlong then
					entry = entry .. "\\, " .. math.abs(math.floor(latlong.x * 10000)/10000)
					if latlong.x < 0 then
						entry = entry .. "°S " 
					else 
						entry = entry .. "°N "
					end
					
					entry = entry .. math.abs(math.floor(latlong.z * 10000)/10000)
					if latlong.z < 0 then
						entry = entry .. "°W"
					else 
						entry = entry .. "°E"
					end
				end

				entry = entry .. "\\, " .. pnotes[i]

				if i ~= #pcoords then
					entry = entry .. ","
				end

				table.insert(coordsList, entry)
			end
		end
	end

	mc_student_coordinates[#mc_student_coordinates] = "textlist[0.4,0.7;12.2,6.4;coordlist;" .. table.concat(coordsList, "") .. "]"
	minetest.show_formspec(player:get_player_name(), "mc_student:coordinates", table.concat(mc_student_coordinates,""))
end

local function record_coordinates(player,message)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pmeta = player:get_meta()
		local pos = player:get_pos()
		local realmID = pmeta:get_int("realm")
		temp = minetest.deserialize(pmeta:get_string("coordinates"))

		if temp == nil then
			datanew = {
				realms = { realmID, },
				coords = { pos, }, 
				notes = { message, },
			}
		else
			table.insert(temp.realms, realmID)
			table.insert(temp.coords, pos)
			table.insert(temp.notes, message)
			datanew = {realms = temp.realms, coords = temp.coords, notes = temp.notes, }
		end

		pmeta:set_string("coordinates", minetest.serialize(datanew))
		temp = nil
		minetest.chat_send_player(player:get_player_name(), player:get_player_name() ..": Your position was recorded in your notebook.")
		show_coordinates(player)
	end
end
------------------------


------------------------------------
--- FORMSPEC AND TOOL MANAGEMENT ---
------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pmeta = player:get_meta()

	if string.sub(formname, 1, 10) ~= "mc_student" then
		return false
	end

	local wait = os.clock()
	while os.clock() - wait < 0.05 do end --popups don't work without this

	if fields.back then
		show_student_menu(player)
	end

	if formname == "mc_student:menu" then
		if fields.spawn then
			local spawnRealm = mc_worldManager.GetSpawnRealm()
			spawnRealm:TeleportPlayer(player)
        elseif fields.report then
			show_report(player)
		elseif fields.coordinates then
			show_coordinates(player)
		elseif fields.classrooms then
			-- show_accesscode(player)
			show_classrooms(player)
		elseif fields.marker then
			show_marker(player)
		elseif fields.taskstudent then
			local pname = player:get_player_name()
			if minetest_classroom.currenttask ~= nil then
				minetest.show_formspec(pname, "task:instructions", minetest_classroom.currenttask)
			else
				minetest.chat_send_player(pname,pname..": No task was found. Message your instructor if you were expecting a task.")
			end
		end
	end

	if formname == "mc_student:classrooms" then
		local event = minetest.explode_textlist_event(fields.realms)

		if fields.realms then
			if event.type == "CHG" then
				selectedClassroom = event.index
			end
		elseif fields.join then
			local realm = classroomRealms[selectedClassroom]
			realm:TeleportPlayer(player)
		end
	end

	if formname == "mc_student:report" then
		-- Checking for nil (caused by player pressing escape instead of Back) ensures the game does not crash
		if fields.report ~= " " and fields.report ~= nil then
			local pname = player:get_player_name()

			-- Count the number of words, by counting for replaced spaces
			-- Number of spaces = Number of words - 1
			local _, count = string.gsub(fields.report, " ", "")
			if count == 0 then
				return false, "If you're reporting a player, you should" ..
					" also include a reason why."
			end

			local msg = pname .. " reported: " .. fields.report

			-- Append list of teachers in-game
			local teachers = ""
			for teacher in pairs(minetest_classroom.mc_students.teachers) do
				teachers = teachers .. teacher .. ", "
			end

			if #minetest_classroom.mc_students.teachers then
				local msg = '[REPORT] ' .. msg .. " (teachers online: " .. teachers:sub(1, -3) .. ")"
				-- Send report to any teacher currently connected
				for teacher in pairs(minetest_classroom.mc_students.teachers) do
					minetest.chat_send_player(teacher, minetest.colorize("#FF00FF", msg))
					minetest.sound_play("report_alert", {to_player = teacher, gain = 1.0, pitch = 1.0,}, true)

				end
			end

			-- Archive the report in mod storage
			local key = pname.." "..tostring(os.date("%d-%m-%Y %H:%M:%S"))
			minetest_classroom.reports:set_string(key,
			minetest.write_json(fields.report))

			-- Archive the report in the chatlog
			chatlog.write_log(pname,'[REPORT] '..fields.report)
		elseif fields.report == nil then
			return true
		else
			minetest.chat_send_player(player:get_player_name(),minetest.colorize("#FF0000","Error: Please add a message to your report."))
		end
	end

	if formname == "mc_student:marker" then
		if fields.message then
			place_marker(player,fields.message)
		elseif fields.message == nil then
			return true
		end
	end

	if formname == "mc_student:coordinates" then
		local event = minetest.explode_textlist_event(fields.coordlist)

		if fields.record then
			record_coordinates(player,fields.note)
		elseif fields.coordlist then
			if event.type == "CHG" then
				selectedCoord = event.index
			end
		elseif fields.go then
			if selectedCoord ~= 0 then
				local new_pos = minetest.deserialize(pmeta:get_string("coordinates")).coords[selectedCoord]
				player:set_pos(new_pos)
			end
		elseif fields.delete then
			local data = minetest.deserialize(pmeta:get_string("coordinates"))
			local newCoords, newNotes, newRealms = {}, {}, {}	

			for i,coord in ipairs(data.coords) do
				if i ~= selectedCoord then
					table.insert(newCoords, coord)
					table.insert(newNotes, data.notes[i])
					table.insert(newRealms, data.realms[i])
				end
			end

			local newData = {coords = newCoords, notes = newNotes, realms = newRealms}
			pmeta:set_string("coordinates", minetest.serialize(newData))
			show_coordinates(player)
		elseif fields.clear then
			pmeta:set_string("coordinates", nil)
			show_coordinates(player)
		end
	end

	if formname == "mc_student:accesscode" or formname == "mc_student:accesscode_fail" then
		if fields.exit then
			return
		end

		local pname = player:get_player_name()

		-- Get the classrooms from modstorage
		local temp = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))

		if temp ~= nil then
			-- Get the classroom accesscodes
			local loc = check_access_code(fields.accesscode,temp.access_code)
			if loc then
				-- Check if the student is currently registered for this course
				local pmeta = player:get_meta()
				local pdata = minetest.deserialize(pmeta:get_string("classrooms"))
				-- Validate against modstorage
				local mdata = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))
				if pdata == nil then
					-- This is the first time the student registers for any course
					local classroomdata = {
						course_code = { mdata.course_code[loc] },
						section_number = { mdata.section_number[loc] },
						start_year = { mdata.start_year[loc] },
						start_month = { mdata.start_month[loc] },
						start_day = { mdata.start_day[loc] },
						end_year = { mdata.end_year[loc] },
						end_month = { mdata.end_month[loc] },
						end_day = { mdata.end_day[loc] },
						realm_id = { mdata.realm_id[loc] },
					}
					pmeta:set_string("classrooms", minetest.serialize(classroomdata))
				else
					-- Student has already registered for another classroom
					table.insert(pdata.course_code, mdata.course_code[loc])
					table.insert(pdata.section_number, mdata.section_number[loc])
					table.insert(pdata.start_year, mdata.start_year[loc])
					table.insert(pdata.start_month, mdata.start_month[loc])
					table.insert(pdata.start_day, mdata.start_day[loc])
					table.insert(pdata.end_year, mdata.end_year[loc])
					table.insert(pdata.end_month, mdata.end_month[loc])
					table.insert(pdata.end_day, mdata.end_day[loc])
					local classroomdata = {
						course_code = pdata.course_code,
						section_number = pdata.section_number,
						start_year = pdata.start_year,
						start_month = pdata.start_month,
						start_day = pdata.start_day,
						end_year = pdata.end_year,
						end_month = pdata.end_month,
						end_day = pdata.end_day,
						realm_id = pdata.realm_id,
					}
				end

				-- Check if the access code is expired
				if tonumber(mdata.end_year[loc]) < tonumber(os.date("%Y")) and months[mdata.end_month[loc]] < tonumber(os.date("%m")) and tonumber(mdata.end_day[loc]) < tonumber(os.date("%d")) then
					minetest.chat_send_player(pname,pname..": The access code you entered has expired. Please contact your instructor.")
				else

                    local realm = Realm.GetRealm(mdata.realm_id[loc])

                    if (realm ~= nil) then

                        local students = realm:get_data("students")
                        if students == nil then
                            students = {}
                        end
                        students[player:get_player_name()] = true
                        realm:set_data("students", students)

                        realm:TeleportPlayer(player)
                        minetest.chat_send_player(pname, pname .. ": You have been teleported to the classroom.")
                    end
				end
			else
				show_accesscode_fail(player)
			end
		else
			return
		end
	end
end)

-- The student notebook for accessing the student actions
minetest.register_tool(tool_name , {
	description = "Notebook for students",
	inventory_image = "notebook.png",
	_mc_tool_privs = priv_table,
	
	on_use = function (itemstack, player, pointed_thing)
        local pname = player:get_player_name()
		if mc_helpers.checkPrivs(player,priv_table) then
			show_student_menu(player)
		end
	end,
	
	on_drop = function(itemstack, dropper, pos)
	end,
})
-------------------------------


----------------------
--- MARKER HELPERS ---
----------------------

-- Functions and variables for placing markers
hud = mhud.init()
markers = {}
local MARKER_LIFETIME = 30
local MARKER_RANGE = 150

function add_marker(pname, message, pos, owner)
	if not hud:get(pname, "marker_" .. owner) then
		hud:add(pname, "marker_" .. owner, {
			hud_elem_type = "waypoint",
			world_pos = pos,
			precision = 1,
			color = 0xFF0000, -- red
			text = message
		})
	else
		hud:change(pname, "marker_" .. owner, {
			world_pos = pos,
			text = message
		})
	end
end

function markers.add(pname, msg, pos)

	if markers[pname] then
		markers[pname].timer:cancel()
	end

	markers[pname] = {
		msg = msg, pos = pos,
		timer = minetest.after(MARKER_LIFETIME, markers.remove, pname),
	}

	for _, player in pairs(minetest.get_connected_players()) do
		add_marker(player, msg, pos, pname)
	end
end

function markers.remove(pname)
	if markers[pname] then
		markers[pname].timer:cancel()

		for _, player in pairs(minetest.get_connected_players()) do
			hud:remove(player, "marker_" .. pname)
		end

		markers[pname] = nil
	end
end

-- Legacy code, keep for convenience
minetest.register_chatcommand("m", {
	description = "Place a marker in your look direction",
	privs = {interact = true, shout = true},
	func = function(name, param)

		local player = minetest.get_player_by_name(name)
		local pos1 = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)

		if param == "" then
			param = "Look here!"
		end

		local ray = minetest.raycast(
			pos1, vector.add(pos1, vector.multiply(player:get_look_dir(), MARKER_RANGE),
			true, false
		))
		local pointed = ray:next()

		if pointed and pointed.type == "object" and pointed.ref == player then
			pointed = ray:next()
		end

		if not pointed then
			return false, "Can't find anything to mark, too far away!"
		end

		local message = string.format("m [%s]: %s", name, param)
		local pos

		if pointed.type == "object" then
			local concat
			local obj = pointed.ref
			local entity = obj:get_luaentity()

			-- If object is a player, append player name to display text
			-- Else if obj is item entity, append item description and count to str.
			if obj:is_player() then
				concat = obj:get_player_name()
			elseif entity then
				if entity.name == "__builtin:item" then
					local stack = ItemStack(entity.itemstring)
					local itemdef = minetest.registered_items[stack:get_name()]

					-- Fallback to itemstring if description doesn't exist
					concat = itemdef.description or entity.itemstring
					concat = concat .. " " .. stack:get_count()
				end
			end

			pos = obj:get_pos()
			if concat then
				message = message .. " <" .. concat .. ">"
			end
		else
			pos = pointed.under
		end

		markers.add(name, message, pos)

		return true, "Marker is placed!"
	end
})

function place_marker(player,message)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		local pos1 = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)

		local ray = minetest.raycast(
			pos1, vector.add(pos1, vector.multiply(player:get_look_dir(), MARKER_RANGE),
			true, false
		))
		local pointed = ray:next()

		if message == "" then
			message = "Look here!"
		end

		if pointed and pointed.type == "object" and pointed.ref == player then
			pointed = ray:next()
		end

		if not pointed then
			return false, minetest.chat_send_player(pname,pname..": Nothing found or too far away.")
		end

		local message = string.format("m [%s]: %s", pname, message)
		local pos

		if pointed.type == "object" then
			local concat
			local obj = pointed.ref
			local entity = obj:get_luaentity()

			-- If object is a player, append player name to display text
			-- Else if obj is item entity, append item description and count to str.
			if obj:is_player() then
				concat = obj:get_player_name()
			elseif entity then
				if entity.name == "__builtin:item" then
					local stack = ItemStack(entity.itemstring)
					local itemdef = minetest.registered_items[stack:get_name()]

					-- Fallback to itemstring if description doesn't exist
					concat = itemdef.description or entity.itemstring
					concat = concat .. " " .. stack:get_count()
				end
			end

			pos = obj:get_pos()
			if concat then
				message = message .. " <" .. concat .. ">"
			end
		else
			pos = pointed.under
		end

		markers.add(pname, message, pos)
		minetest.chat_send_player(pname,pname..": You placed a marker.")
		return true
	else
		minetest.chat_send_player(pname,pname..": You are not allowed to place markers. Please submit a report from your notebook to request this privilege.")
	end
end





-- -- Define the Access Code formspec
-- local mc_student_accesscode = {
-- 	"formspec_version[5]",
-- 	"size[5,3]",
-- 	"label[0.6,0.5;Enter an Access Code]",
-- 	"pwdfield[0.5,0.9;3.9,0.8;accesscode;]",
-- 	"button_exit[0.9,2;3,0.8;submit;Submit]",
-- 	"button_exit[4.4,0;0.6,0.5;exit;X]"
-- }

-- local function show_accesscode(player)
-- 	if mc_helpers.checkPrivs(player,priv_table) then
-- 		local pname = player:get_player_name()
-- 		minetest.show_formspec(pname, "mc_student:accesscode", table.concat(mc_student_accesscode,""))
-- 		return true
-- 	end
-- end

-- local mc_student_accesscode_fail = {
-- 	"formspec_version[5]",
-- 	"size[5,4.2]",
-- 	"label[0.6,0.5;Enter Your Access Code]",
-- 	"pwdfield[0.5,0.9;3.9,0.8;accesscode;]",
-- 	"button_exit[0.9,2;3,0.8;submit;Submit]",
-- 	"label[0.9,3.2;Invalid access code.]",
-- 	"label[1.2,3.7;Please try again.]",
-- 	"button_exit[4.4,0;0.6,0.5;exit;X]"
-- }

-- local function show_accesscode_fail(player)
-- 	if mc_helpers.checkPrivs(player,priv_table) then
-- 		local pname = player:get_player_name()
-- 		minetest.show_formspec(pname, "mc_student:accesscode_fail", table.concat(mc_student_accesscode_fail,""))
-- 		return true
-- 	end
-- end