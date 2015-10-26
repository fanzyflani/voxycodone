function split(s, tok)
	local l = {}

	local i = 1
	local tlen = #tok
	while true do
		local j = s:find(tok, i)

		if not j then
			table.insert(l, s:sub(i))
			return l
		end

		table.insert(l, s:sub(i, j-1))
		i = j+tlen
	end
end

S = {}
do
	local priv = {}
	priv.shader = nil
	priv.uniflist = {}
	setmetatable(S, {
		__index = function(t, key)
			if priv.shader == nil then
				error("cannot get uniform locations for nil")
			end

			local l = priv.uniflist[priv.shader]
			if l[key] == nil then
				l[key] = shader.uniform_location_get(priv.shader, key)
			end
			return l[key]
		end,
		__call = function(func, typ, ...)
			if typ == "use" then
				priv.shader = ...
			else
				error(string.format("unhandled method call to S: %s", typ or "(nil/false)"))
			end
		end
	})
end


