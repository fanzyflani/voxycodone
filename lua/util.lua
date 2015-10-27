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
	local fns = {}
	priv.shader = nil
	priv.uniflist = {}

	function fns.USE(shader)
		priv.shader = shader
	end

	setmetatable(S, {
		__index = function(t, key)
			if fns[key] then
				return fns[key]
			end

			if priv.shader == nil then
				error("cannot get uniform locations for nil")
			end

			local l = priv.uniflist[priv.shader]
			if l[key] == nil then
				l[key] = shader.uniform_location_get(priv.shader, key)
			end
			return l[key]
		end,
	})
end


