




for i=0,8 do

	local nici = 1
	if i == 0 then
		nici = 0
	end

	minetest.register_node("springs:sluice_gate_"..i, {
		description = "Sluice Gate",
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				-- top bar
				{-.3, .3, -.15, .3, .5, .15},
				
				-- sides
				{-.5, -.5, -.4, -.3, .5, .4},
				{.3, -.5, -.4, .5, .5, .4},
				
				-- rod
				{-.01, .5, -.01, .01, 1.0, .01 },
				-- handle
				{-.02, 1.0 - .01, -.02, .02, 1.01, .02 },
				{-.06, 1.0 - .01, -.01, .06, 1.0, .01 },
				{-.01, 1.0 - .01, -.06, .01, 1.0, .06 },
				
				-- gate
				{-.3, -.5 + (.08 * i), -.02, .3, .3, .02},
				
			},
		},
		connects_to = { "group:water_pipe", "group:water_fixture" },
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		tiles = { "default_copper_block.png" },
		walkable = true,
		groups = { cracky = 3, sluice_gate = i, not_in_creative_inventory = nici },
		drop = "springs:sluice_gate_0",
		on_place = minetest.rotate_node,
		on_punch = function(pos)
			local node = minetest.get_node(pos)
			local n = math.min(8, i + 1)
			minetest.set_node(pos, {name = "springs:sluice_gate_"..n, param2 = node.param2})
		end,
		on_rightclick = function(pos)
			local node = minetest.get_node(pos)
			local n = math.max(0, i - 1)
			minetest.set_node(pos, {name = "springs:sluice_gate_"..n, param2 = node.param2})
		
		end,

		
	})

end

minetest.register_abm({
	nodenames = {"group:sluice_gate"},
	neighbors = {"group:fresh_water"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local node     = minetest.get_node(pos)
		
		local rate = minetest.get_item_group(node.name, "sluice_gate") * 4
		if rate == 0 then
			return
		end
		
		local back_dir = minetest.facedir_to_dir(node.param2)
		local backpos = vector.add(pos, back_dir) 
		local backnode = minetest.get_node(backpos) 
	--	print("back node: "..backnode.name)
		local backlevel = minetest.get_node_level(backpos)
		
		local front_dir = vector.multiply(back_dir, -1)
		local frontpos = vector.add(pos, front_dir)
		local frontnode = minetest.get_node(frontpos)
		local frontlevel = minetest.get_node_level(frontpos)
		
		if frontnode.name ~= "air" and frontnode.name ~= "springs:water" then
	--		print("not front")
			return
		end
		if backnode.name ~= "air" and backnode.name ~= "springs:water" then
	--		print("not back: ".. backnode.name)
			return
		end
		
	--	print("back level: "..backlevel)
	--	print("front level: "..frontlevel)
		
		if math.abs(backlevel - frontlevel) < 2 then
			return
		end
		
		if frontlevel > backlevel then
			local tmppos = backpos
			local tmpnode = backnode
			local tmplevel = backlevel
			backnode = frontnode
			backpos = frontpos
			backlevel = frontlevel
			frontnode = tmpnode
			frontpos = tmppos
			frontlevel = tmplevel
		end
		
		-- from back to front
		
		local max_cap = 64 - frontlevel
		local max_avail = backlevel
		local diff = backlevel - frontlevel
		local half = math.floor(diff / 2)
		local trans = math.min(rate, math.min(half, math.min(max_avail, max_cap)))
	--	print("trans: " .. trans)
	--	print("front pos: "..frontpos.x ..","..frontpos.y.. ","..frontpos.z)
		minetest.set_node_level(backpos, backlevel - trans)
		if frontnode.name == "air" then
			minetest.set_node(frontpos, {name= "springs:water"})
			minetest.set_node_level(frontpos, trans)
		else
	--		print("setting front level: ".. (frontlevel + trans))
			minetest.set_node_level(frontpos, frontlevel + trans)
		end
		
		
		
	end
})



