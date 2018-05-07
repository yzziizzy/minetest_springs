


local networks = {}
local net_members = {}
local netname = 1

local mod_storage = minetest.get_mod_storage()


	
networks = minetest.deserialize(mod_storage:get_string("networks")) or {}
net_members = minetest.deserialize(mod_storage:get_string("net_members")) or {}
netname = minetest.deserialize(mod_storage:get_int("netname")) or 1


local function save_data() 
	--print("saving")
	
	mod_storage:set_string("networks", minetest.serialize(networks))
	mod_storage:set_string("net_members", minetest.serialize(net_members))
	mod_storage:set_int("netname", minetest.serialize(netname))
end


minetest.register_node("springs:intake", {
	description = "Intake",
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = {{-.1, -.1, -.1, .1, .1, .1}},
		-- connect_bottom =
		connect_front = {{-.1, -.1, -.5,  .1, .1, .1}},
		connect_left = {{-.5, -.1, -.1, -.1, .1,  .1}},
		connect_back = {{-.1, -.1,  .1,  .1, .1,  .5}},
		connect_right = {{ .1, -.1, -.1,  .5, .1,  .1}},
		connect_bottom = {{ -.1, -.5, -.1,  .1, .1,  .1}},
	},
	connects_to = { "group:water_pipe", "group:water_fixture" },
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_tin_block.png" },
	walkable = true,
	groups = { cracky = 3, water_fixture = 1, },
	on_construct = function(pos) 
		print("\nintake placed at "..pos.x..","..pos.y..","..pos.z)
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
		check_net({x=pos.x + 1, y=pos.y, z=pos.z})
		check_net({x=pos.x - 1, y=pos.y, z=pos.z})
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
		
minetest.register_abm({
	nodenames = {"springs:intake"},
	neighbors = {"group:fresh_water"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local hash = minetest.hash_node_position(pos)
		
		pos.y = pos.y + 1
		local unode = minetest.get_node(pos)
		if unode.name ~= "springs:water" then
			return
		end
		
		local ulevel = minetest.get_node_level(pos)
		if ulevel < 1 then
			print("!!!!!!!!!!!! intake level less than one?")
			return
		end
		
		local rate = math.max(1, math.ceil(ulevel / 2))
		
		local phash = net_members[hash]
		local pnet = networks[phash]
		local cap = 64
		local take = math.max(0, cap - pnet.buffer)
		pnet.buffer = pnet.buffer + take
		if ulevel - rate > 0 then
			minetest.set_node_level(pos, ulevel - take)
		else
			minetest.set_node(pos, {name = "air"})
		end
	end
})



minetest.register_node("springs:spout", {
	description = "Spout",
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = {{-.1, -.1, -.1, .1, .1, .1}},
		-- connect_bottom =
		connect_front = {{-.1, -.1, -.5,  .1, .1, .1}},
		connect_left = {{-.5, -.1, -.1, -.1, .1,  .1}},
		connect_back = {{-.1, -.1,  .1,  .1, .1,  .5}},
		connect_right = {{ .1, -.1, -.1,  .5, .1,  .1}},
		connect_top = {{ -.1, -.1, -.1,  .1, .5,  .1}},
	},
	connects_to = { "group:water_pipe", "group:water_fixture" },
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_copper_block.png" },
	walkable = true,
	groups = { cracky = 3, water_fixture = 1, },
	on_construct = function(pos) 
		print("\nspout placed at "..pos.x..","..pos.y..","..pos.z)
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
					pnet.outputs[hash] = 1
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
		check_net({x=pos.x + 1, y=pos.y, z=pos.z})
		check_net({x=pos.x - 1, y=pos.y, z=pos.z})
		check_net({x=pos.x, y=pos.y, z=pos.z + 1})
		check_net({x=pos.x, y=pos.y, z=pos.z - 1})
		
		
		if found_net == 0 then 

			print("new network: hash: ".. hash .." name: " ..netname); 
			networks[hash] = {
				hash = hash,
				pos = {x=pos.x, y=pos.y, z=pos.z},
				name = netname,
				count = 1,
				outputs = {
					[hash] = 1,
				},
				inputs = {},
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
		
		
minetest.register_abm({
	nodenames = {"springs:spout"},
-- 	neighbors = {"group:fresh_water"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local hash = minetest.hash_node_position(pos)
		local phash = net_members[hash]
		local pnet = networks[phash]
		
		if pnet.buffer <= 0 then
			return -- no water in the pipe
		end
		
		pos.y = pos.y - 1
		
		local bnode = minetest.get_node(pos)
		local avail =  10 -- pnet.buffer / #pnet.outputs
		if bnode.name == "springs:water" then
			local blevel = minetest.get_node_level(pos)
			local cap = 64 - blevel
			local out = math.min(cap, math.min(avail, cap))
			--print("cap: ".. cap .." avail: ".. avail .. " out: "..out) 
			pnet.buffer = pnet.buffer - out
			minetest.set_node_level(pos, blevel + out)
		elseif bnode.name == "air" then
			local out = math.min(64, math.max(0, avail))
			pnet.buffer = pnet.buffer - out
			minetest.set_node(pos, {name = "springs:water"})
			minetest.set_node_level(pos, out)
		end
		
	
	end
})
		

minetest.register_node("springs:pipe", {
	description = "water pipe",
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = {{-.1, -.1, -.1, .1, .1, .1}},
		-- connect_bottom =
		connect_front = {{-.1, -.1, -.5,  .1, .1, .1}},
		connect_left = {{-.5, -.1, -.1, -.1, .1,  .1}},
		connect_back = {{-.1, -.1,  .1,  .1, .1,  .5}},
		connect_right = {{ .1, -.1, -.1,  .5, .1,  .1}},
		connect_top = {{ -.1, -.1, -.1,  .1, .5,  .1}},
		connect_bottom = {{ -.1, -.5, -.1,  .1, .1,  .1}},
	},
	connects_to = { "group:water_pipe", "group:water_fixture" },
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_steel_block.png" },
	walkable = true,
	groups = { cracky = 3, water_pipe = 1, },
	
	on_construct = function(pos) 
		print("\npipe placed at "..pos.x..","..pos.y..","..pos.z)
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
		check_net({x=pos.x + 1, y=pos.y, z=pos.z})
		check_net({x=pos.x - 1, y=pos.y, z=pos.z})
		check_net({x=pos.x, y=pos.y, z=pos.z + 1})
		check_net({x=pos.x, y=pos.y, z=pos.z - 1})
		
		
		if found_net == 0 then 

			print("new network: hash: ".. hash .." name: " ..netname); 
			networks[hash] = {
				hash = hash,
				pos = {x=pos.x, y=pos.y, z=pos.z},
				name = netname,
				count = 1,
				outputs = {},
				inputs = {},
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
