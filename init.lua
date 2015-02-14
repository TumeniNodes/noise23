-- Parameters

local YZERO = 0 -- Average world surface level
local TERSCA = 96 -- Vertical terrain scale
local YWATER = 1
local STABLE = 2 -- Number of stone nodes required to support biome above
local TSTONE = 0.03 -- Controls depth of stone below surface
local YSAND = 4 -- Y of beach top
local TTUN = -0.4 -- Biome noise threshold for tundra
local TDES = 0.4 -- Biome noise threshold for desert

-- Noise parameters

-- 3D noise

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x=384, y=256, z=384},
	seed = 5900033,
	octaves = 5,
	persist = 0.63,
	lacunarity = 2.0,
	--flags = ""
}

-- 2D noise

local np_biome = {
	offset = 0,
	scale = 1,
	spread = {x=768, y=768, z=768},
	seed = -188900,
	octaves = 3,
	persist = 0.4,
	lacunarity = 2.0,
	--flags = ""
}

-- Set mapgen parameters

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname="singlenode", flags="nolight"})
end)

-- Initialize noise objects to nil

local nobj_terrain = nil
local nobj_biome = nil

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	local t0 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_stone    = minetest.get_content_id("default:stone")
	local c_sand     = minetest.get_content_id("default:sand")
	local c_water    = minetest.get_content_id("default:water_source")
	local c_lava     = minetest.get_content_id("default:lava_source")
	local c_grass    = minetest.get_content_id("default:dirt_with_grass")
	local c_dirt     = minetest.get_content_id("default:dirt")
	local c_desand   = minetest.get_content_id("default:desert_sand")
	local c_destone  = minetest.get_content_id("default:desert_stone")
	local c_dirtsnow = minetest.get_content_id("default:dirt_with_snow")

	local sidelen = x1 - x0 + 1
	local ystridevm = sidelen + 32
	--local zstridevm = ystride ^ 2
	local chulens3d = {x=sidelen, y=sidelen+17, z=sidelen}
	local chulens2d = {x=sidelen, y=sidelen, z=1}
	local minpos3d = {x=x0, y=y0-16, z=z0}
	local minpos2d = {x=x0, y=z0}
	
	nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, chulens3d)
	nobj_biome = nobj_biome or minetest.get_perlin_map(np_biome, chulens2d)
	
	local nvals_terrain = nobj_terrain:get3dMap_flat(minpos3d)
	local nvals_biome = nobj_biome:get2dMap_flat(minpos2d)

	local ni3d = 1
	local ni2d = 1
	local stable = {}
	local under = {}
	for z = z0, z1 do
		for x = x0, x1 do
			local si = x - x0 + 1
			stable[si] = 0
		end
		for y = y0 - 16, y1 + 1 do
			local vi = area:index(x0, y, z)
			for x = x0, x1 do
				local si = x - x0 + 1
				local viu = vi - ystridevm
				local n_biome = nvals_biome[ni2d]

				local n_terrain = nvals_terrain[ni3d]
				local grad = (YZERO - y) / TERSCA
				local density = n_terrain + grad

				if y < y0 then
					if density >= TSTONE then
						stable[si] = stable[si] + 1
					elseif density <= 0 then
						stable[si] = 0
					end
					if y == y0 - 1 then
						local nodid = data[vi]
						if nodid == c_stone
						or nodid == c_destone
						or nodid == c_sand
						or nodid == c_desand
						or nodid == c_grass
						or nodid == c_dirt then
							stable[si] = STABLE
						end
					end
				elseif y >= y0 and y <= y1 then
					if density >= TSTONE then
						if n_biome > TDES then
							data[vi] = c_destone
						else
							data[vi] = c_stone
						end
						stable[si] = stable[si] + 1
						under[si] = 0
					elseif density > 0 and density < TSTONE
					and stable[si] >= STABLE then
						if y <= YSAND then
							data[vi] = c_sand
							under[si] = 1 -- beach
						elseif n_biome < TTUN then
							data[vi] = c_dirt
							under[si] = 4 -- tundra
						elseif n_biome > TDES then
							data[vi] = c_desand
							under[si] = 3 -- desert
						else
							data[vi] = c_dirt
							under[si] = 2 -- grassland
						end
					elseif y <= YWATER then
						data[vi] = c_water
						stable[si] = 0
						under[si] = 0
					else -- air, possibly just above surface
						if under[si] == 2 then
							data[viu] = c_grass
						elseif under[si] == 4 then
							data[viu] = c_dirtsnow
						end
						stable[si] = 0
						under[si] = 0
					end
				elseif y == y1 + 1 then
					if density <= 0 and y > YWATER then -- air, possibly just above surface
						if under[si] == 2 then
							data[viu] = c_grass
						elseif under[si] == 4 then
							data[viu] = c_dirtsnow
						end
						stable[si] = 0
						under[si] = 0
					end
				end

				ni3d = ni3d + 1
				ni2d = ni2d + 1
				vi = vi + 1
			end
			ni2d = ni2d - sidelen
		end
		ni2d = ni2d + sidelen
	end
	
	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map(data)
	vm:update_liquids()

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[noise23] "..chugent.." ms  minp ("..x0.." "..y0.." "..z0..")")
end)

