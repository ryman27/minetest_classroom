minetest.set_mapgen_setting('mg_name', 'singlenode', true)
minetest.set_mapgen_setting('flags', 'nolight', true)

Realm.heightMapGenerator = {}
Realm.MapDecorator = {}

local c_stone = minetest.get_content_id("default:stone")
local c_water = minetest.get_content_id("default:water_source")
local c_lava = minetest.get_content_id("default:lava_source")
local c_air = minetest.get_content_id("air")
local c_dirt = minetest.get_content_id("default:dirt")
local c_grass = minetest.get_content_id("default:dirt_with_grass")
local c_sand = minetest.get_content_id("default:sand")
local c_gravel = minetest.get_content_id("default:gravel")

function Realm:GenerateTerrain(seed, seaLevel, heightMapGeneratorName, mapDecoratorName)
    local heightMapGen
    local mapDecorator

    if (Realm.heightMapGenerator[heightMapGeneratorName] == nil) then
        Debug.log("Height map generator " .. heightMapGeneratorName .. " not found.")
    else
        heightMapGen = Realm.heightMapGenerator[heightMapGeneratorName]
    end

    if (Realm.MapDecorator[mapDecoratorName] == nil) then
        Debug.log("Map decorator " .. mapDecoratorName .. " not found.")
    else
        mapDecorator = Realm.MapDecorator[mapDecoratorName]
    end

    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(self.StartPos, self.EndPos)
    local area = VoxelArea:new {
        MinEdge = emin,
        MaxEdge = emax
    }

    local data = vm:get_data()
    local heightMapTable = heightMapGen(self.StartPos, self.EndPos, area, data, seed, seaLevel)
    mapDecorator(self.StartPos, self.EndPos, area, data, heightMapTable, seed, seaLevel)

    Debug.log("Saving and loading map...")

    vm:set_data(data)
    vm:write_to_map()

    -- Set our new spawnpoint
    local oldSpawnPos = self.SpawnPoint
    local surfaceLevel = getTerrainHeight(oldSpawnPos.x, oldSpawnPos.z, seaLevel, perlin, continentality, erosion)

    self:UpdateSpawn(self:WorldToLocalPosition({ x = oldSpawnPos.x, y = surfaceLevel, z = oldSpawnPos.z }))
end

Realm.heightMapGenerator["v1"] = function(startPos, endPos, area, data, seed, seaLevel)
    Debug.log("Calling heightmap generator v1")

    local mainPerlin = minetest.get_perlin(seed, 4, 0.5, 100)
    local erosionPerlin = minetest.get_perlin(seed * 2, 4, 0.5, 400)

    local heightMapTable = {}

    for posZ = startPos.z, endPos.z do
        for posY = startPos.y, endPos.y do
            for posX = startPos.x, endPos.x do
                -- vi, voxel index, is a common variable name here
                local vi = area:index(posX, posY, posZ)

                local surfaceHeight

                if (ptable.get2D(heightMapTable, { x = posX, y = posZ }) == nil) then
                    local noise = mainPerlin:get_2d({ x = posX, y = posZ })
                    local noise2 = erosionPerlin:get_2d({ x = posX, y = posZ })
                    surfaceHeight = math.ceil(seaLevel + (noise * 5) + (noise * noise2 * 20))
                    ptable.store2D(heightMapTable, { x = posX, y = posZ }, surfaceHeight)
                else
                    surfaceHeight = ptable.get2D(heightMapTable, { x = posX, y = posZ })
                end

                if (posY < surfaceHeight) then
                    data[vi] = c_stone
                elseif (posY < seaLevel) then
                    data[vi] = c_water
                else
                    data[vi] = c_air
                end
            end
        end
    end

    return heightMapTable
end

Realm.MapDecorator["v1"] = function(startPos, endPos, area, data, heightMapTable, seed, seaLevel)
    Debug.log("Calling map decorator v1")

    local erosionPerlin = minetest.get_perlin(seed * 2, 4, 0.5, 400)

    for posZ = startPos.z, endPos.z do
        for posY = startPos.y, endPos.y do
            for posX = startPos.x, endPos.x do
                -- vi, voxel index, is a common variable name here
                local vi = area:index(posX, posY, posZ)
                local viAbove = area:index(posX, posY + 1, posZ)
                local viBelow = area:index(posX, posY - 1, posZ)

                if (data[vi] == c_stone) then
                    local surfaceHeight = ptable.get2D(heightMapTable, { x = posX, y = posZ })
                    if (posY > surfaceHeight - ((1 - erosionPerlin:get_2d({ x = posX, y = posZ })) * 5)) then
                        data[vi] = c_dirt
                    end

                    if (posY >= surfaceHeight - 1 and data[vi] == c_dirt) then
                        if (posY <= seaLevel) then
                            data[vi] = c_sand
                            if (data[viBelow] == c_dirt) then
                                data[viBelow] = c_sand
                            end
                        else
                            data[vi] = c_grass
                        end
                    end


                end
            end
        end


    end
end