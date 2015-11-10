-- Temporary emulation layer for to-be-proposed API

do
	local fn, msg = loadfile("root/engine_test/main.lua")

	if not fn then
		print("ERROR loading engine_test/main.lua:", msg)
		error("boot failed!")
	end

	-- Change package path
	package.cpath = "" -- TODO: blank this out
	package.path = "root/engine_test/?.lua"

	-- Set up bin_load layer
	-- XXX: doesn't have path checks. we'll cover those in the C side
	local old_io = io
	io = nil

	function bin_load(fname)
		fname = "root/engine_test/"..fname
		print("OPENING", fname)
		local fp = old_io.open(fname, "rb")
		local ret = fp:read("a"):gsub("\r\n", "\n"):gsub("\r", "\n")
		fp:close()
		return ret
	end

	-- Run!
	return fn(...)
end

