local initialfusemap = {
	andsection = {
		{false,false,false,false}, -- Input 1
		{false,false,false,false}, -- Input /1
		{false,false,false,false}, -- Input 2
		{false,false,false,false}, -- Input /2
		{false,false,false,false}, -- Input 3
		{false,false,false,false}, -- Input /3
		{false,false,false,false}, -- Input 4
		{false,false,false,false}, -- Input /4
--     Outputs:    A     B     C     D
	},
	orsection = {
		{false,false,false,false}, -- Input A
		{false,false,false,false}, -- Input /A
		{false,false,false,false}, -- Input B
		{false,false,false,false}, -- Input /B
		{false,false,false,false}, -- Input C
		{false,false,false,false}, -- Input /C
		{false,false,false,false}, -- Input D
		{false,false,false,false}, -- Input /D
--     Outputs:    1     2     3     4
	},
}

local rules = {
	[1] = {x=0,y=0,z=1}, --North
	[2] = {x=1,y=0,z=0}, --East
	[3] = {x=0,y=0,z=-1}, --South
	[4] = {x=-1,y=0,z=0} --West
}

local function allequal(table,value)
	if #table < 1 then return false end
	local ret = true
	for _,i in pairs(table) do
		ret = ret and (i == value)
	end
	return(ret)
end

local function updatenode(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local lports = minetest.deserialize(meta:get_string("lports")) or {}
	local bin = ""
	for i=4,1,-1 do
		bin = bin..(lports[i] and "1" or "0")
	end
	node.name = string.format("mesegal:gal_%X",tonumber(bin,2))
	minetest.swap_node(pos,node)
end

local function setport(pos,portnum,state)
	local meta = minetest.get_meta(pos)
	local lports = minetest.deserialize(meta:get_string("lports")) or {}
	if lports[portnum] == nil then lports[portnum] = false end
	if lports[portnum] == state then return end
	lports[portnum] = state
	meta:set_string("lports",minetest.serialize(lports))
	updatenode(pos)
	if state then
		mesecon.receptor_on(pos,{rules[portnum]})
	else
		mesecon.receptor_off(pos,{rules[portnum]})
	end
end

local function mergeports(lports,rports)
	local ret = {}
	for i=1,4,1 do
		ret[i] = lports[i] or rports[i]
	end
	return(ret)
end

local function run(pos)
	if mesecon.do_overheat(pos) then
		for i=1,4,1 do
			setport(pos,i,false)
		end
		minetest.set_node(pos,{name="mesegal:gal_burnt"})
	end

	local meta = minetest.get_meta(pos)
	local lports = minetest.deserialize(meta:get_string("lports")) or {}
	local rports = minetest.deserialize(meta:get_string("rports")) or {}
	local mports = mergeports(lports,rports)
	local fuses = minetest.deserialize(meta:get_string("fusemap"))
	if not fuses then return end

	local andinput = {}
	andinput[1] = mports[1]
	andinput[2] = not mports[1]
	andinput[3] = mports[2]
	andinput[4] = not mports[2]
	andinput[5] = mports[3]
	andinput[6] = not mports[3]
	andinput[7] = mports[4]
	andinput[8] = not mports[4]
	local andoutput = {}
	for i=1,4,1 do
		local maskedin = {}
		for j=1,8,1 do
			if fuses.andsection[j][i] then
				table.insert(maskedin,andinput[j])
			end
		end
		andoutput[i] = allequal(maskedin,true)
	end

	local orinput = {}
	orinput[1] = andoutput[1]
	orinput[2] = not andoutput[1]
	orinput[3] = andoutput[2]
	orinput[4] = not andoutput[2]
	orinput[5] = andoutput[3]
	orinput[6] = not andoutput[3]
	orinput[7] = andoutput[4]
	orinput[8] = not andoutput[4]
	local oroutput = {}
	for i=1,4,1 do
		local maskedin = {}
		for j=1,8,1 do
			if fuses.orsection[j][i] then
				table.insert(maskedin,orinput[j])
			end
		end
		oroutput[i] = #maskedin > 0 and not allequal(maskedin,false)
		setport(pos,i,oroutput[i])
	end
end

local function onichange(pos,_,rule,state)
	local port = 0
	if rule.x == 1 then port = 2
	elseif rule.x == -1 then port = 4
	elseif rule.z == 1 then port = 1
	elseif rule.z == -1 then port = 3 end
	if port == 0 then return end
	local meta = minetest.get_meta(pos)
	local rports = minetest.deserialize(meta:get_string("rports")) or {}
	rports[port] = (state == mesecon.state.on)
	meta:set_string("rports",minetest.serialize(rports))
	run(pos)
end

local function updateformspec(pos)
	local meta = minetest.get_meta(pos)
	local fusemap = minetest.deserialize(meta:get_string("fusemap")) or {}
	local fs = "size[10,10]background[-0.5,-0.5;11,11;mesegal_fs_bg.png]"

	fs = fs.."label[1.25,0;AND SECTION]"
	fs = fs.."vertlabel[0,4;INPUT PINS]"
	fs = fs.."label[0.5,1;1]"
	fs = fs.."label[0.5,2;/1]"
	fs = fs.."label[0.5,3;2]"
	fs = fs.."label[0.5,4;/2]"
	fs = fs.."label[0.5,5;3]"
	fs = fs.."label[0.5,6;/3]"
	fs = fs.."label[0.5,7;4]"
	fs = fs.."label[0.5,8;/4]"
	fs = fs.."label[1,9.5;OUTPUT SIGNALS TO OR SECTION]"
	fs = fs.."label[1,9;A]"
	fs = fs.."label[1.75,9;B]"
	fs = fs.."label[2.5,9;C]"
	fs = fs.."label[3.25,9;D]"
	for i=1,4,1 do
		for j=1,8,1 do
			fs = fs..string.format("button[%s,%s;1,1;and%s%s;%s]",i*0.75,j,i,j,(fusemap.andsection[j][i] and "X" or ""))
		end
	end

	fs = fs.."label[6.25,0;OR SECTION]"
	fs = fs.."vertlabel[5,4;INPUT SIGNALS]"
	fs = fs.."label[5.5,1;A]"
	fs = fs.."label[5.5,2;/A]"
	fs = fs.."label[5.5,3;B]"
	fs = fs.."label[5.5,4;/B]"
	fs = fs.."label[5.5,5;C]"
	fs = fs.."label[5.5,6;/C]"
	fs = fs.."label[5.5,7;D]"
	fs = fs.."label[5.5,8;/D]"
	fs = fs.."label[6,9.5;OUTPUT PINS]"
	fs = fs.."label[6,9;1]"
	fs = fs.."label[6.75,9;2]"
	fs = fs.."label[7.5,9;3]"
	fs = fs.."label[8.25,9;4]"
	for i=1,4,1 do
		for j=1,8,1 do
			fs = fs..string.format("button[%s,%s;1,1;or %s%s;%s]",i*0.75+5,j,i,j,(fusemap.orsection[j][i] and "X" or ""))
		end
	end

	meta:set_string("formspec",fs)
end

local function handlefields(pos,_,fields)
	local meta = minetest.get_meta(pos)
	local fusemap = minetest.deserialize(meta:get_string("fusemap"))
	for k,v in pairs(fields) do
		local section = string.sub(k,1,3)
		if section == "and" then
			local i = tonumber(string.sub(k,4,4))
			local j = tonumber(string.sub(k,5,5))
			fusemap.andsection[j][i] = not fusemap.andsection[j][i]
		elseif section == "or " then
			local i = tonumber(string.sub(k,4,4))
			local j = tonumber(string.sub(k,5,5))
			fusemap.orsection[j][i] = not fusemap.orsection[j][i]
		end
	end
	meta:set_string("fusemap",minetest.serialize(fusemap))
	updateformspec(pos)
	run(pos)
end

for i=0,15,1 do
	local bits = {}
	bits[1] = i%2 == 1
	bits[2] = math.floor(i/2)%2 == 1
	bits[3] = math.floor(i/4)%2 == 1
	bits[4] = math.floor(i/8)%2 == 1

	local irules = {}
	local orules = {}
	for i=1,4,1 do
		if bits[i] then
			table.insert(orules,rules[i])
		else
			table.insert(irules,rules[i])
		end
	end

	local mesecons = {
		effector = {
			rules = irules,
			action_change = onichange,
		},
		receptor = {
			state = mesecon.state.on,
			rules = orules,
		},
	}

	local tiles = {"mesegal_sides.png","mesegal_sides.png","mesegal_sides.png","mesegal_sides.png","mesegal_sides.png"}
	local top = "mesecons_wire_on.png^mesegal_top.png"
	if bits[1] then top = top.."^mesegal_porton.png" end
	if bits[2] then top = top.."^(mesegal_porton.png^[transformR270)" end
	if bits[3] then top = top.."^(mesegal_porton.png^[transformFY)" end
	if bits[4] then top = top.."^(mesegal_porton.png^[transformR90)" end
	table.insert(tiles,1,top)

	local groups = {dig_immediate=2,overheat=1}
	if i > 0 then groups.not_in_creative_inventory = 1 end

	minetest.register_node(string.format("mesegal:gal_%X",i),{
		paramtype = "light",
		drawtype = "nodebox",
		description = "Mesecons GAL",
		node_box = {
			type = "fixed",
			fixed = {{-0.5,-0.5,-0.5,0.5,-7/16,0.5}},
		},
		drop = "mesegal:gal_0",
		tiles = tiles,
		inventory_image = "mesecons_wire_on.png^mesegal_top.png",
		groups = groups,
		mesecons = mesecons,
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("fusemap",minetest.serialize(initialfusemap))
			updateformspec(pos)
		end,
		on_receive_fields = handlefields,
	})
end

minetest.register_node("mesegal:gal_burnt",{
	paramtype = "light",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {{-0.5,-0.5,-0.5,0.5,-7/16,0.5}},
	},
	drop = "mesegal:gal_0",
	tiles = {"mesegal_burnt.png","mesegal_sides.png","mesegal_sides.png","mesegal_sides.png","mesegal_sides.png","mesegal_sides.png"},
	groups = {dig_immediate=2,not_in_creative_inventory=1},
})

minetest.register_craft({
	output = "mesegal:gal_0",
	recipe = {
		{"mesecons_gates:and_off","mesecons_gates:and_off","mesecons_gates:or_off",},
		{"mesecons_gates:and_off","mesecons_gates:and_off","mesecons_gates:or_off",},
		{"mesecons_gates:and_off","mesecons_gates:and_off","mesecons:wire_00000000_off",},
	}
})
