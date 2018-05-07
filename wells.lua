








minetest.register_node("springs:well_pipe", {
	description = "Well Pipe Section",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- pump bar
			{-.05, .5, -.05, .05, .65, .05 },
			
			-- casing
			{-.2, -.5, -.2, .2, .5, .2 },
			{-.10, -.5, -.25, .10, .5, .25 },
			{-.25, -.5, -.10, .25, .5, .10 },
			
		},
	},
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_steel_block.png" },
	walkable = true,
	groups = { cracky = 3 },
	
})




local function check_well_pipe(pos) 
	
	
	
	
	
	
end



minetest.register_node("springs:well_head", {
	description = "Well Head",
	drawtype = "connected",
	node_box = {
		type = "fixed",
		fixed = {
			-- housing
			{-.3, -.3, -.3, .3, .3, .3 },
			
			-- casing
			{-.2, -.5, -.2, .2, 0, .2 },
			{-.10, -.5, -.25, .10, 0, .25 },
			{-.25, -.5, -.10, .25, 0, .10 },
			
		},
		connect_front = {{-.1, -.1, -.5,  .1, .1, .1}},
		connect_left = {{-.5, -.1, -.1, -.1, .1,  .1}},
		connect_back = {{-.1, -.1,  .1,  .1, .1,  .5}},
		connect_right = {{ .1, -.1, -.1,  .5, .1,  .1}},
	},
	connects_to = { "group:water_pipe" },
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_steel_block.png" },
	walkable = true,
	groups = { cracky = 3, water_fixture = 1 },

	on_punch = function(pos)
		----local node = minetest.get_node(pos)
		--local n = math.min(8, i + 1)
		--minetest.set_node(pos, {name = "springs:sluice_gate_"..n, param2 = node.param2})
	end,
	on_construct = function(pos) 
		print("\nwell head placed at "..pos.x..","..pos.y..","..pos.z)
		local hash = minetest.hash_node_position(pos)
		
		local merge_list = {}
		local current_net = nil
		local found_net = 0
		
				
		local check_net = function(npos)
			local nhash = minetest.hash_node_position(npos)
			local nphash = net_members[nhash] 
			if nphash ~= nil then
				local pnet = networks[nphash]
				
				if nil == current_net then
					print("joining existing network: ".. pnet.name)
					net_members[hash] = nphash
					current_net = nphash
					pnet.count = pnet.count + 1
					pnet.inputs[hash] = 1
					table.insert(merge_list, pnet)
				elseif current_net == nphash then
					print("alternate connection to existing network")
				else
					print("found seconday network: "..pnet.name)
					table.insert(merge_list, pnet)
				end
				
				found_net = 1
			end
		end
		
		
			
		
		check_net({x=pos.x, y=pos.y - 1, z=pos.z})
		check_net({x=pos.x, y=pos.y + 1, z=pos.z})
		check_net({x=pos.x, y=pos.y, z=pos.z + 1})
		check_net({x=pos.x, y=pos.y, z=pos.z - 1})
		
		
		if found_net == 0 then 

			print("new network: hash: ".. hash .." name: " ..netname); 
			networks[hash] = {
				hash = hash,
				pos = {x=pos.x, y=pos.y, z=pos.z},
				name = netname,
				count = 1,
				inputs = {
					[hash] = 1,
				},
				outputs = {},
				buffer = 0,
			}
			
			net_members[hash] = hash
			
			netname = netname + 1
		end
		
		
		
		
		if #merge_list > 1 then 
			print("\n merging "..#merge_list.." networks")
			
			local biggest = {count = 0}
			local mlookup = {}
			
			for _,n in ipairs(merge_list) do
				mlookup[n.hash] = 1 
				if n.count > biggest.count then
					biggest = n
				end
			end
			
			mlookup[biggest.hash] = 0
			
			for k,v in pairs(net_members) do
				if mlookup[v] == 1 then
					net_members[k] = biggest.hash
				end
			end
			
			
			for _,n in ipairs(merge_list) do
				if n.hash ~= biggest.hash then
					biggest.count = biggest.count + n.count
					n.count = 0
				end
			end
			
		end
		
		
		save_data()
		
	end
})














