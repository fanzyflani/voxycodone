-- Temporary emulation layer for to-be-proposed API
test = sandbox.new("blind", [=[
foo = "bar"
function hax()
	print("hi")
end
]=])
print(test)
for k,v in pairs(test) do
	print(">", k, v)
end
print(string)
print(test.string)
print(pcall(test.hax)) -- NOT RECOMMENDED

do
	--MAIN_MODULE = "engine_test"
	--MAIN_MODULE = "menu"
	MAIN_MODULE = "bnlmaps"
	local fn, msg = loadfile(""..MAIN_MODULE.."/main.lua")

	if not fn then
		print("ERROR loading main.lua:", msg)
		error("boot failed!")
	end

	loadfile("emul.lua")

	local old_bin_load = bin_load
	function bin_load(fname, ...)
		return old_bin_load(""..MAIN_MODULE.."/"..fname, ...)
	end

	-- TODO: client sandboxes
	-- Yes, this thing works, but we lack proper messaging hooks.
	--vm_client = sandbox.new("plugin", MAIN_MODULE)
	--misc.exit()

	-- Run!
	return fn(...)
end

