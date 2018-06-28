
springs = {}


local modpath = minetest.get_modpath("springs")
dofile(modpath.."/pipes.lua")
dofile(modpath.."/sluice.lua")
dofile(modpath.."/pump.lua")
dofile(modpath.."/wells.lua")

--[[
TODO:

water filters
pipe inlet/outlet pressure checks
broken outlet sharing
non-connected pipes and splitters
fix wells
better springs texture
optimize static water
pumps
fix spout and intake nodeboxes

crafts

galvanized-ish pipes (coat in tin)

]]



minetest.register_node("springs:spring", {
	description = "Spring",
	tiles = {"default_cobble.png^default_river_water.png"},
	--paramtype = "light",  
	--leveled = 64,
	--alpha = 160,
	drop = "default:cobble",
	--drowning = 1,
	walkable = true, -- because viscosity doesn't work for regular nodes, and the liquid hack can't be leveled
	
--	post_effect_color = {a = 103, r = 30, g = 76, b = 120},
	groups = { puts_out_fire = 1, cracky = 1, is_ground_content = 1, cools_lava = 1},
	sounds = default.node_sound_water_defaults(),
})


minetest.register_node("springs:water", {
	description = "node ",
	drawtype = "nodebox",
	paramtype = "light",  
	tiles = {
		{
			name = "default_river_water_source_animated.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2.0,
			},
		},
	},
	special_tiles = {
		{
			name = "default_river_water_source_animated.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2.0,
			},
			backface_culling = false,
		},
	},
	leveled = 64,
	alpha = 160,
	drop = "",
	drowning = 1,
	walkable = false, -- because viscosity doesn't work for regular nodes, and the liquid hack can't be leveled
	climbable = true, -- because viscosity doesn't work for regular nodes, and the liquid hack can't be leveled
	pointable = false,
	diggable = false,
	buildable_to = true,
	
-- 	       liquid_viscosity = 14,
--        liquidtype = "source",
--        liquid_alternative_flowing = "springs:water",
--        liquid_alternative_source = "springs:water",
--        liquid_renewable = false,
--        liquid_range = 0,
--     groups = {crumbly=3,soil=1,falling_node=1},
	post_effect_color = {a = 103, r = 30, g = 76, b = 90},
	groups = { puts_out_fire = 1, liquid = 3, cools_lava = 1, fresh_water=1},
	sounds = default.node_sound_water_defaults(),
	node_box = {
		type = "leveled",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}, -- NodeBox1
		}
	}
})



-- this is a special node used to optimize large pools of water
-- its flowing abm runs much less frequently
minetest.register_node("springs:water_full", {
	description = "node ",
	drawtype = "nodebox",
	paramtype = "light",  
	tiles = {
		{
			name = "default_river_water_source_animated.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2.0,
			},
		},
	},
	special_tiles = {
		{
			name = "default_river_water_source_animated.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2.0,
			},
			backface_culling = false,
		},
	},
	leveled = 64,
	alpha = 160,
	drop = "",
	drowning = 1,
	walkable = false, -- because viscosity doesn't work for regular nodes, and the liquid hack can't be leveled
	climbable = true, -- because viscosity doesn't work for regular nodes, and the liquid hack can't be leveled
	pointable = false,
	diggable = false,
	buildable_to = true,
	
-- 	       liquid_viscosity = 14,
--        liquidtype = "source",
--        liquid_alternative_flowing = "springs:water",
--        liquid_alternative_source = "springs:water",
--        liquid_renewable = false,
--        liquid_range = 0,
--     groups = {crumbly=3,soil=1,falling_node=1},
	post_effect_color = {a = 103, r = 30, g = 76, b = 90},
	groups = { puts_out_fire = 1, liquid = 3, cools_lava = 1, fresh_water=1},
	sounds = default.node_sound_water_defaults(),
	node_box = {
		type = "leveled",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}, -- NodeBox1
		}
	}
})



-- spring
minetest.register_abm({
	nodenames = {"springs:spring"},
	neighbors = {"group:fresh_water", "air"},
	interval = 5,
	chance = 60,
	action = function(pos)
-- 		local mylevel = minetest.get_node_level(pos)
		
	--	print("spring at: "..pos.x..","..pos.y..","..pos.z)
		local air_nodes = minetest.find_nodes_in_area(
			{x=pos.x - 1, y=pos.y - 1, z=pos.z - 1},
			{x=pos.x + 1, y=pos.y, z=pos.z + 1},
			{"group:fresh_water", "air"}
		)
		
		if nil == air_nodes or #air_nodes == 0 then 
			return
		end

		local tpos = air_nodes[math.random(#air_nodes)]
		
		-- calculate flow rate based on absolute location
		local prate = (minetest.hash_node_position(pos) % 48)
		local amount = math.random(1, 16) + prate
		
		local t = minetest.get_node(tpos)
		if t.name == "air" then
			minetest.set_node(tpos, {name = "springs:water"})
			minetest.set_node_level(tpos, amount)
		else -- it's group:fresh_water
			local tlevel = minetest.get_node_level(tpos)
			minetest.set_node_level(tpos, math.min(64, tlevel + amount))
		end
		
	end
})

-- evaporation
minetest.register_abm({
	nodenames = {"group:fresh_water"},
	neighbors = {"group:fresh_water", "air"},
	interval = 5,
	chance = 10,
	action = function(pos)
		local mylevel = minetest.get_node_level(pos)
		if math.random(16 - minetest.get_node_light(pos)) == 1 then
			if mylevel > 1 then
				minetest.set_node_level(pos, mylevel - 1)
			else
				minetest.set_node(pos, {name = "air"})
			end
		end
	end
})


local soak = {
	["default:cobble"] = 10,
	["default:desert_cobble"] = 10,
	["default:mossycobble"] = 9,
	["default:dirt"] = 2,
	["default:dirt_with_grass"] = 2,
	["default:dirt_with_grass_footsteps"] = 2,
	["default:dirt_with_dry_grass"] = 2,
	["default:dirt_with_coniferous_litter"] = 2,
	["default:dirt_with_rainforest_litter"] = 1,
	["default:gravel"] = 8,
	["default:coral_orange"] = 6,
	["default:coral_brown"] = 6,
	["default:coral_skeleton"] = 6,
	["default:sand"] = 6,
	["default:sand_with_kelp"] = 6,
	["default:desert_sand"] = 7,
	["default:silver_sand"] = 7,
	["default:snow"] = 4,
	["default:snowblock"] = 4,
	["default:leaves"] = 60,
	["default:bush_leaves"] = 60,
	["default:jungleleaves"] = 60,
	["default:pine_needles"] = 60,
	["default:acacia_leaves"] = 60,
	["default:acacia_bush_leaves"] = 60,
	["default:aspen_leaves"] = 60,
	
	-- dilution
	["default:water_source"] = 65,
	["default:water_flowing"] = 65,
	["default:river_water_source"] = 65,
	["default:river_water_flowing"] = 65,
	
	-- boiling -- TODO: steam effect
	["default:lava_source"] = 65,
	["default:lava_flowing"] = 65,
	
	-- no ladder hacks
	["default:ladder_wood"] = 65,
--	["default:ladder_steel"] = 65, -- need to figure out a way for water to flow through ladders
	["default:sign_wall_wood"] = 65,
	["default:sign_wall_steel"] = 65,

	["default:fence_wood"] = 65,
	["default:fence_acacia_wood"] = 65,
	["default:fence_junglewood"] = 65,
	["default:fence_pine_wood"] = 65,
	["default:fence_aspen_wood"] = 65,
	
	["default:torch"] = 65,
	["carts:rail"] = 65,
	["carts:brakerail"] = 65,
	["carts:powerrail"] = 65,


}

local soak_names = {}
for n,_ in pairs(soak) do
	table.insert(soak_names, n)
end



-- soaking sideways
minetest.register_abm({
	nodenames = {"group:fresh_water"},
	neighbors = soak_names,
	interval = 4,
	chance = 10,
	action = function(pos)
		--	print("\nsoak ")
		local soak_nodes = minetest.find_nodes_in_area(
			{x=pos.x - 1, y=pos.y, z=pos.z - 1},
			{x=pos.x + 1, y=pos.y, z=pos.z + 1},
			soak_names
		)
		
		local mylevel = minetest.get_node_level(pos)
		local total_loss = 0
		for _,spos in ipairs(soak_nodes) do
			local sn = minetest.get_node(spos)
			total_loss = total_loss + soak[sn.name]
			
			if 1 == math.random(120 / mylevel) then
				minetest.set_node(spos, {name = "air"})
			end
			
		end
		
		if total_loss == 0 then
			return
		end
		
		--print("loss: ".. total_loss)
		

		local remain = mylevel - (total_loss * (mylevel / 64))
		if remain > 0 then
			minetest.set_node_level(pos, remain)
		else
			minetest.set_node(pos, {name="air"})
		end
	end
})

-- de-stagnation (faster flowing)
minetest.register_abm({
	nodenames = {"springs:water_full"},
	neighbors = {"air"},
	interval = 5,
	chance = 1,
	action = function(pos)
		-- if it's near air it might flow
		minetest.set_node(pos, {name = "springs:water"})
	end
})
	
-- flowing
minetest.register_abm({
	nodenames = {"springs:water"},
	neighbors = {"group:fresh_water", "air"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local mylevel = minetest.get_node_level(pos)
-- 		print("\n mylevel ".. mylevel)
	
		-- falling
		local below = {x=pos.x, y=pos.y - 1, z=pos.z}
		local nbelow = minetest.get_node(below).name
		if nbelow == "air" then
			minetest.set_node(below, {name="springs:water"})
			minetest.set_node_level(below, mylevel)
			minetest.set_node(pos, {name="air"})
			return
		elseif nbelow == "springs:water" then
			local blevel = minetest.get_node_level(below)
			if blevel < 64 then
				local sum = mylevel + blevel
				minetest.set_node_level(below, math.min(64, sum))
				
				if sum > 64 then
					mylevel = sum - 64
					minetest.set_node_level(pos, mylevel)
					-- keep flowing the liquid. this speeds up cascades
				else
					minetest.set_node(pos, {name="air"})
					return
				end
			end
		else -- check soaking
			local rate = soak[nbelow]
			if rate ~= nil then
				local remains = mylevel - rate
				if remains > 0 then
					minetest.set_node_level(pos, remains)
				else
					minetest.set_node(pos, {name="air"})
				end
				
			if 1 == math.random(120 / mylevel) then
				minetest.set_node(below, {name = "air"})
			end
				
				mylevel = remains 
				--return -- keep the fluid mechanics
			end
		end
	
		local air_nodes = minetest.find_nodes_in_area(
			{x=pos.x - 1, y=pos.y - 1, z=pos.z - 1},
			{x=pos.x + 1, y=pos.y, z=pos.z + 1},
			"air"
		)
		
		
		
		
-- 		print("x: "..pos.x.." y: "..pos.y.." z: "..pos.z)
-- 		print("air list len ".. #air_nodes)
		local off = math.random(#air_nodes)
		
		for i = 1,#air_nodes do
			--local theirlevel = minetest.get_node_level(fp)
			local fp = air_nodes[((i + off) % #air_nodes) + 1]
			if mylevel >= 2 then
				local half = math.ceil(mylevel / 2)
				
				minetest.set_node_level(pos, mylevel - half)
				minetest.set_node(fp, {name= "springs:water"})
				minetest.set_node_level(fp, half)
-- 				minetest.check_for_falling(fp)
				return
			end
		end
		
		local flow_nodes = minetest.find_nodes_in_area(
			{x=pos.x - 1, y=pos.y , z=pos.z - 1},
			{x=pos.x + 1, y=pos.y, z=pos.z + 1},
			"group:fresh_water"
		)
		
-- 		print("x: "..pos.x.." y: "..pos.y.." z: "..pos.z)
-- 		print("list len ".. #flow_nodes)
		local off = math.random(#flow_nodes)
		
		for i = 1,#flow_nodes do
			local fp = flow_nodes[((i + off) % #flow_nodes) + 1]
			local theirlevel = minetest.get_node_level(fp)
-- 			print("theirlevel "..theirlevel)
			if mylevel - theirlevel >= 2 then
				local diff = (mylevel - theirlevel)
				local half = math.ceil(diff / 2)
				
				minetest.set_node_level(pos, mylevel - half)
				minetest.set_node_level(fp, theirlevel + (diff - half))
				return
			end
		end
			
-- 			local n = minetest.get_node(fp);
-- 			-- check above to make sure it can get here
-- 			local na = minetest.get_node({x=fp.x, y=fp.y+1, z=fp.z})
-- 			
-- 	--		print("name: " .. na.name .. " l: " ..g)
-- 			if na.name == "default:river_water_flowing" or na.name == "default:river_water_flowing" then
-- 				minetest.set_node(fp, {name=node.name})
-- 				minetest.set_node(pos, {name=n.name})
-- 				return
-- 			end
-- 		end
		
		
		-- stagnation: this may not work
		if mylevel == 64 then
			--print("stagnating ".. pos.x .. ","..pos.y..","..pos.z)
			minetest.set_node(pos, {name = "springs:water_full"})
		end
	end
})



-- surface water
minetest.register_ore({
	ore_type       = "scatter",
	ore            = "springs:spring",
	wherein        = {"default:dirt_with_grass", "default:dirt_with_coniferous_litter", "default:dirt_with_rainforest_litter"},
	clust_scarcity = 64 * 64 * 64,
	clust_num_ores = 1,
	clust_size     = 1,
	y_min          = -20,
	y_max          = 200,
})

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "springs:spring",
	wherein        = "default:dirt",
	clust_scarcity = 48 * 48 * 48,
	clust_num_ores = 1,
	clust_size     = 1,
	y_min          = -20,
	y_max          = 200,
})


-- ground water
minetest.register_ore({
	ore_type       = "scatter",
	ore            = "springs:spring",
	wherein        = "default:stone",
	clust_scarcity = 16 * 16 * 16,
	clust_num_ores = 3,
	clust_size     = 3,
	y_min          = -50,
	y_max          = -10,
})

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "springs:spring",
	wherein        = "default:stone",
	clust_scarcity = 8 * 8 * 8,
	clust_num_ores = 5,
	clust_size     = 4,
	y_min          = -50,
	y_max          = -25,
})



-- deep water - rare but bountiful
minetest.register_ore({
	ore_type       = "scatter",
	ore            = "springs:spring",
	wherein        = "default:stone",
	clust_scarcity = 64 * 64 * 64,
	clust_num_ores = 12,
	clust_size     = 6,
	y_min          = -32000,
	y_max          = -100,
})


-- minetest.register_ore({
-- 	ore_type       = "scatter",
-- 	ore            = "springs:spring",
-- 	wherein        = "default:stone",
-- 	clust_scarcity = 8 * 8 * 8,
-- 	clust_num_ores = 16,
-- 	clust_size     = 5,
-- 	y_min          = -50,
-- 	y_max          = -40,
-- })

-- TODO: desert stone, sandstone

