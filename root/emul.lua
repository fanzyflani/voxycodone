-- Lua file API emulation layer

-- Prep package module
package = {}
package.loaded = {}
package.preload = {}

-- Change package path
package.cpath = ""
package.path = "./?.lua"
--[[
package.searchpath = function(name, path, sep, rep)
	sep = sep or "."
	rep = rep or "/"
end
]]
package.loadlib = nil
package.searchpath = function(...)
	-- TODO: make this work on the C side
	return nil
end

package.searchers = {
	function (fname)
		return package.preload[fname]
	end,

	function (fname)
		print("HONK", fname)
		--print(package.searchpath(fname, package.path))
		fname = fname:gsub("[.]", "/")

		-- XXX: if we were doing this for real we'd support separators
		local path = package.path
		local out_fname = path:gsub("[?]", fname)
		return function(src_fname, ...)
			print(fname, src_fname, out_fname)
			local v = bin_load(out_fname)
			return load(v, out_fname, "t", _ENV)(...)
		end
	end,
}

function require(modname)
	if package.loaded[modname] then 
		return package.loaded[modname]
	end

	local k, v
	for k, v in ipairs(package.searchers) do
		local ldr = v(modname)
		if ldr then
			local val = ldr(modname, nil)
			if val == nil then val = true end
			package.loaded[modname] = val
			return val
		end
	end
end

-- Prep io module
-- TODO!
io = {}

