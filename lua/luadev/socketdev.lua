if not luadev then
	print"nah"
	return
end

hook.Remove("Think", "LuaDev-Socket") -- upvalues will be lost
if IsValid(SOCKETDEV) then
	SOCKETDEV:Remove()
	SOCKETDEV = nil
end

collectgarbage()
collectgarbage() -- finalizers will be scheduled for execution in the first pass, but will only execute in the second pass

local ok, why
if #file.Find("lua/bin/gmcl_luasocket*.dll", "GAME") > 0 then
	ok, why = pcall(require, "luasocket")
else
	why = "File not found"
end

if not ok then
	print(("\n\n\n\nUnable to load luasocket module (%s), LuaDev socket API will be unavailable\n\n\n\n"):format(tostring(why)))
	return
end

local sock = socket.tcp()
assert(sock:bind("127.0.0.1", 27099))
sock:settimeout(0)
assert(sock:listen(0))
	
local methods = {
	self = luadev.RunOnSelf,
	sv = luadev.RunOnServer,
	sh = luadev.RunOnShared,
	cl = luadev.RunOnClients,
	ent = function(contents, who)
		contents = "ENT = {}; local ENT=ENT; " .. contents .. "; scripted_ents.Register(ENT, '" .. who:sub(0, -5) .. "')"
		luadev.RunOnShared(contents, who)
	end,
	client = luadev.RunOnClient,
}

SOCKETDEV = vgui.Create("Panel")
SOCKETDEV:SetMouseInputEnabled(false)
SOCKETDEV:SetKeyBoardInputEnabled(false)
SOCKETDEV:SetSize(0, 0)
SOCKETDEV.Think = function()
	local cl, a, b, c = sock:accept()
	if cl then
		system.FlashWindow()

		if cl:getpeername() ~= "127.0.0.1" then
			print("Refused", cl:getpeername())
			cl:shutdown()
			return
		end

		cl:settimeout(0)

		local method = cl:receive("*l")
		local who = cl:receive("*l")

		if method and methods[method] then
			if method == "client" then
				local to = cl:receive("*l")
				local contents = cl:receive("*a")
				methods[method](contents, {easylua and easylua.FindEntity(to) or player.GetByID(tonumber(to))}, who)
			else
				local contents = cl:receive("*a")
				methods[method](contents, who)
			end
		end
		cl:shutdown()
	end
end