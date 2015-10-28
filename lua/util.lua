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
		priv.uniflist[shader] = priv.uniflist[shader] or {}
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
			if l[key] == nil or l[key] == -1 then
				local spew = (l[key] == nil)
				l[key] = shader.uniform_location_get(priv.shader, key)
				if spew then
					print(priv.shader, l[key], misc.gl_error(), key)
				end
			end
			return l[key]
		end,
	})
end

function bin_load(fname)
	local fp = io.open(fname, "rb")
	local ret = fp:read("a"):gsub("\r\n", "\n"):gsub("\r", "\n")
	fp:close()
	return ret
end

function glslpp_parse(s)
	local idx

	while true do
		idx = s:find("\n%", 1, true)
		if not idx then break end
		idx = idx + 1
		local nidx = s:find("\n", idx+1, true) or s:len()
		if s:sub(idx, idx+8) == "%include " then
			local fname = s:sub(idx+8+1, nidx-1)
			print("{"..fname.."}")
			s = s:sub(1, idx-1) .. bin_load(fname) .. s:sub(nidx+1)
		else
			print(s:sub(idx, nidx-1))
			error("unhandled preproc statement")
		end
	end

	return s
end

