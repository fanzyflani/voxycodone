-- Temporary emulation layer for to-be-proposed API

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

	-- Run!
	return fn(...)
end

