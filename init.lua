-- noise23 0.1.1 by paramat
-- For latest stable Minetest and back to 0.4.8
-- Depends default
-- License: code WTFPL

-- Parameters

local YMIN = 6000
local YMAX = 8000
local TERCEN = 7000 -- Terrain centre. Average terrain level
local YWATER = 7000 -- Approximate water surface y, is rounded down to near base of chunk
local TERSCA = 128 -- Terrain scale in nodes, typical height of mountains
local TSTONE = 0.04 -- Density threshold for stone, depth of stone below surface
local STABLE = 2 -- Minimum number of stacked stone nodes in column required to support sand

-- 3D noise for terrain

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x=512, y=256, z=512}, -- squashed perlin noise, y spread is half
	seed = 5900033,
	octaves = 6,
	persist = 0.67
}

-- 2D noise for biomes

local np_biome = {
	offset = 0,
	scale = 1,
	spread = {x=512, y=512, z=512}, -- spread is still stated with xyz values
	seed = -188900,
	octaves = 4,
	persist = 0.5
}

-- Stuff

noise23 = {}

waty = (80 * math.floor((WATY + 32) / 80)) - 32 + 15 -- sets water surface to 16 nodes above chunk base

-- Nodes

minetest.register_node("noise23:flosand", {
	description = "Turquoise Float Sand",
	tiles = {"noise23_flosand.png"},
	groups = {crumbly=3, falling_node=1},
	sounds = default.node_sound_sand_defaults(),
})

minetest.register_node("noise23:stone", {
	description = "N23 Stone",
	tiles = {"default_stone.png"},
	groups = {cracky=3},
	drop = "default:stone",
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("noise23:desertstone", {
	description = "N23 Desert Stone",
	tiles = {"default_desert_stone.png"},
	groups = {cracky=3},
	drop = "default:desert_stone",
	sounds = default.node_sound_stone_defaults(),
})

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	if minp.y < YMIN or maxp.y > YMAX then
		return
	end

	local t1 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	
	print ("[noise23] chunk minp ("..x0.." "..y0.." "..z0..")")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_air = minetest.get_content_id("air")
	local c_n23stone = minetest.get_content_id("noise23:stone")
	local c_n23destone = minetest.get_content_id("noise23:desertstone")
	local c_sand = minetest.get_content_id("default:sand")
	local c_desand = minetest.get_content_id("default:desert_sand")
	local c_flosand = minetest.get_content_id("noise23:flosand")
	local c_water = minetest.get_content_id("default:water_source")
	
	local sidelen = x1 - x0 + 1
	local chulens = {x=sidelen, y=sidelen, z=sidelen}
	local minposxyz = {x=x0, y=y0, z=z0}
	local minposxz = {x=x0, y=z0}
	
	local nvals_terrain = minetest.get_perlin_map(np_terrain, chulens):get3dMap_flat(minposxyz)
	local nvals_biome = minetest.get_perlin_map(np_biome, chulens):get2dMap_flat(minposxz)
	
	local nixyz = 1 -- 3D noise index
	local nixz = 1 -- 2D noise index
	local stable = {}
	for z = z0, z1 do -- for each xy plane progressing northwards
		for x = x0, x1 do
			local si = x - x0 + 1
			local nodename = minetest.get_node({x=x,y=y0-1,z=z}).name
			if nodename == "air"
			or nodename == "default:water_source" then
				stable[si] = 0
			else
				stable[si] = STABLE
			end
		end
		for y = y0, y1 do -- for each x row progressing upwards
			local vi = area:index(x0, y, z)
			for x = x0, x1 do -- for each node do
				local si = x - x0 + 1
				local grad = (TCEN - y) / GRAD
				local density = nvals_terrain[nixyz] + grad
				local n_biome = nvals_biome[nixz] -- biome noise for node
				local biome = false -- set biome id to undefined
				if n_biome > 0.46 + math.random() * 0.04 then -- set biome id
					biome = 3
				elseif n_biome < -0.5 + math.random() * 0.04 then
					biome = 1
				else
					biome = 2
				end
				if density >= STOT then
					if biome == 3 then
						data[vi] = c_n23destone
					else -- biomes 1 and 2
						data[vi] = c_n23stone
					end
					stable[si] = stable[si] + 1
				elseif density >= 0 and density < STOT and stable[si] >= 2 then
					if biome == 3 then
						data[vi] = c_desand
					elseif biome == 1 then
						data[vi] = c_flosand
					else -- biome = 2
						data[vi] = c_sand
					end
				elseif y <= waty then
					data[vi] = c_water
					stable[si] = 0
				else
					data[vi] = c_air
					stable[si] = 0
				end
				nixyz = nixyz + 1 -- increment 3D noise index
				nixz = nixz + 1 -- increment 2D noise index
				vi = vi + 1
			end
			nixz = nixz - 80 -- rewind 2D noise index by 80 nodes for next x row above
		end
		nixz = nixz + 80 -- fast-forward 2D noise index by 80 nodes for next northward xy plane
	end
	
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
	local chugent = math.ceil((os.clock() - t1) * 1000)
	print ("[noise23] "..chugent.." ms")
end)