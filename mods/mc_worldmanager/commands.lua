-- All the functionality from these commands will added to a realm book.
-- These commands are currently just for testing


local commands = {}

minetest.register_chatcommand("localPos", {
    privs = {
        teacher = true,
    },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        local requestedRealm = Realm.GetRealmFromPlayer(player)

        if (requestedRealm == nil) then
            return false, "Player is not listed in a realm OR current realm has been deleted; Try teleporting to a different realm and then back..."
        end

        local position = requestedRealm:WorldToLocalPosition(player:get_pos())
        return true, "Your position in the local space of realm " .. param .. " is x: " .. position.x .. " y: " .. position.y .. " z: " .. position.z
    end,
})

commands["new"] = {
    func = function(name, params)
        local realmName = tostring(params[1])
        if (realmName == "" or realmName == nil) then
            realmName = "Unnamed Realm"
        end
        local sizeX = tonumber(params[2])
        if (sizeX == nil or sizeX == 0) then
            sizeX = 40
        end
        local sizeY = tonumber(params[3])
        if (sizeY == nil or sizeY == 0) then
            sizeY = 40
        end
        local sizeZ = tonumber(params[4]) or 40
        if (SizeZ == nil or SizeZ == 0) then
            SizeZ = 40
        end
        local newRealm = Realm:New(realmName, { x = sizeX, y = sizeY, z = sizeZ })
        newRealm:CreateGround()
        newRealm:CreateBarriers()

        return true, "created new realm with ID: " .. newRealm.ID
    end }

commands["delete"] = {
    func = function(name, params)
        local realmID = params[1]

        if (realmID == nil) then
            return false, "No realm ID specified"
        end

        if (realmID == mc_worldManager.spawnRealmID) then
            return false, "Cannot delete the spawn realm."
        end

        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm of ID:" .. realmID .. " does not exist."
        end
        requestedRealm:Delete()
    end }

commands["list"] = {
    func = function(name, params)
        minetest.chat_send_player(name, "Realm Name : Realm ID")
        for i, t in pairs(Realm.realmDict) do
            minetest.chat_send_player(name, t.Name .. " : " .. t.ID)
        end

        return true
    end }

commands["info"] = {
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm does not exist."
        end

        local spawn = requestedRealm.SpawnPoint
        local startPos = requestedRealm.StartPos
        local endPos = requestedRealm.EndPos

        return true, "Realm " .. realmID .. " has a spawn point of "
                .. "x:" .. tostring(spawn.x) .. " y:" .. tostring(spawn.y) .. " z:" .. tostring(spawn.z)
                .. "; startPos of "
                .. "x:" .. tostring(startPos.x) .. " y:" .. tostring(startPos.y) .. " z:" .. tostring(startPos.z)
                .. "; endPos of "
                .. "x:" .. tostring(endPos.x) .. " y:" .. tostring(endPos.y) .. " z:" .. tostring(endPos.z)
    end }

commands["tp"] = {
    privs = { teleport = true },
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm of ID:" .. realmID .. " does not exist."
        end

        local player = minetest.get_player_by_name(name)
        requestedRealm:TeleportPlayer(player)

        return true, "teleported to: " .. realmID
    end }

commands["walls"] = {
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm of ID:" .. realmID .. " does not exist."
        end

        requestedRealm:CreateBarriers()
    end }

commands["schematic"] = {
    func = function(name, params)
        if (params[1] == "list") then
            table.remove(params, 1)

            minetest.chat_send_player(name, "Key : Filepath")
            for i, t in pairs(schematicManager.schematics) do
                minetest.chat_send_player(name, i .. " : " .. t)
            end
            return true
        elseif (params[1] == "save") then
            table.remove(params, 1)
            local realmID = params[1]
            local requestedRealm = Realm.GetRealm(tonumber(realmID))

            if (requestedRealm == nil) then
                return false, "Requested realm of ID:" .. realmID .. " does not exist."
            end

            local subparam = params[2]

            if (subparam == "" or subparam == nil) then
                subparam = "old"
            end

            local path = requestedRealm:Save_Schematic(name, subparam)
            return true, "Saved realm with ID " .. realmID .. " at path: " .. path
        elseif (params[1] == "load") then
            table.remove(params, 1)
            local realmName = params[1]
            if (realmName == "" or realmName == nil) then
                realmName = "Unnamed Realm"
            end

            local key = params[1]
            if (key == nil) then
                key = ""
            end

            local schematic, config = schematicManager.getSchematic(key)

            if (config == nil) then
                return false, "schematic key: " .. tostring(key) .. " config file has not been registered with the system."
            end

            local newRealm = Realm:NewFromSchematic(realmName, key)
            return true, "creat[ing][ed] new realm with name: " .. newRealm.Name .. "and ID: " .. newRealm.ID .. " from schematic with key " .. key
        else
            return false, "unknown subcommand. Try realm schematic list | realm schematic save | realm schematic load"
        end
    end }

commands["setspawn"] = {
    func = function(name, params)
        local player = minetest.get_player_by_name(name)

        local requestedRealm = Realm.GetRealmFromPlayer(player)

        local position = requestedRealm:WorldToLocalPosition(player:get_pos())

        requestedRealm:UpdateSpawn(position)

        return true, "Updated spawnpoint for realm with ID: " .. requestedRealm.ID
    end }

commands["setspawnrealm"] = {
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm of ID:" .. realmID .. " does not exist."
        end

        local success = mc_worldManager.SetSpawnRealm(requestedRealm)

        if (success) then
            return true, "Updated the spawn realm to realm with ID: " .. realmID
        else
            return false, "something went wrong... could not update the spawn realm."
        end
    end }

commands["consolidate"] = {
    func = function(name, params)
        Realm.consolidateEmptySpace()
        Realm.SaveDataToStorage()
        return true, "consolidated realms"
    end }

commands["help"] = {
    func = function(name, params)
        local helpString = ""
        for k, v in pairs(commands) do
            helpString = helpString .. k .. " | "
        end
        return true, helpString
    end }

commands["define"] = {
    func = function(name, params)
        -- this is really hacky, we should come up with a better way to do this...

        local name = tostring(params[1])
        local pos1X = tonumber(params[2])
        local pos1Y = tonumber(params[3])
        local pos1Z = tonumber(params[4])
        local pos2X = tonumber(params[5])
        local pos2Y = tonumber(params[6])
        local pos2Z = tonumber(params[7])

        if (name == nil or pos1X == nil or pos1Y == nil or pos1Z == nil or pos2X == nil or pos2Y == nil or pos2Z == nil) then
            return false, "missing command parameters"
        end

        local pos1 = { x = pos1X, y = pos1Y, z = pos1Z }
        local pos2 = { x = pos2X, y = pos2Y, z = pos2Z }
        local spawnPos = { x = (pos1.x + pos2.x) / 2, y = pos2.y - 5, z = (pos1.z + pos2.z) / 2 }

        local newRealm = {
            Name = name,
            ID = Realm.realmCount + 1,
            StartPos = pos1,
            EndPos = pos2,
            SpawnPoint = spawnPos,
            PlayerJoinTable = nil,
            PlayerLeaveTable = nil,
            RealmDeleteTable = nil,
            MetaStorage = { }
        }

        Realm.realmCount = newRealm.ID
        Realm:Restore(newRealm)
    end }

commands["players"] = {
    func = function(name, params)


        if (params[1] == "list") then
            local realmID = params[2]
            local requestedRealm = Realm.GetRealm(tonumber(realmID))
            if (requestedRealm == nil) then
                return false, "Requested realm of ID:" .. realmID .. " does not exist."
            end

            local realmPlayerList = requestedRealm:get_tmpData("Inhabitants")

            if (realmPlayerList == nil) then
                return false, "no players found in realm player list."
            end

            Debug.log(minetest.serialize(realmPlayerList))

            for k, v in pairs(realmPlayerList) do
                minetest.chat_send_player(name, k)
            end

            return true, "listed all players in realm."
        elseif (params[1] == "scan") then
            Realm.ScanForPlayerRealms()
            return true, "re-associated players with realms."

        end

        return false, "unknown sub-command."
    end
}

minetest.register_chatcommand("realm", {
    params = "Subcommand Realm ID Option",
    func = function(name, param)
        local params = mc_helpers.split(param, " ")
        local subcommand = params[1]
        table.remove(params, 1)

        if (commands[subcommand] ~= nil) then
            if (commands[subcommand].privs == nil) then
                commands[subcommand].privs = { teacher = true }
            end
            local has, missing = minetest.check_player_privs(name, commands[subcommand].privs)
            if not has then
                local missingPermsString = ""
                for k, v in pairs(missing) do
                    missingPermsString = missingPermsString .. v .. ", "
                end

                return false, "You do not have permission to use this command. Missing command(s): " .. missingPermsString
            end

            return commands[subcommand].func(name, params)
        else
            return false, "Unknown subcommand. Use 'realm help' for a list of sub-commands."
        end
    end,
})