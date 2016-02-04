local function skipws(s, pos)
	while pos <= #s do
		local c = s:sub(pos,pos)
		if c == " " or c == "\n" or c == "\r" or c == "\t" then
			pos = pos + 1
		else
			return pos
		end
	end
end

function json_parse(s, pos)
	pos = pos or 1
	pos = skipws(s, pos)
	local c = s:sub(pos,pos)
	if c == '{' then
		local l = {}
		pos = skipws(s, pos + 1)
		while s:sub(pos, pos) ~= '}' do
			local key, val
			key, pos = json_parse(s, pos)
			pos = skipws(s, pos)
			if s:sub(pos, pos) ~= ':' then error("expected : after key") end
			pos = skipws(s, pos + 1)
			val, pos = json_parse(s, pos)
			l[key] = val
			if s:sub(pos, pos) == '}' then break
			elseif s:sub(pos, pos) ~= ',' then error("expected , or } after obj elem") end
			pos = skipws(s, pos + 1)
		end
		pos = skipws(s, pos + 1)
		return l, pos

	elseif c == '[' then
		local l = {}
		local key = 1
		pos = skipws(s, pos + 1)
		while s:sub(pos, pos) ~= ']' do
			local val
			val, pos = json_parse(s, pos)
			pos = skipws(s, pos)
			l[key] = val
			key = key + 1
			if s:sub(pos, pos) == ']' then break
			elseif s:sub(pos, pos) ~= ',' then error("expected , or ] after list elem") end
			pos = skipws(s, pos + 1)
		end
		pos = skipws(s, pos + 1)
		return l, pos

	elseif c == '"' then
		pos = pos + 1
		local os = ""
		while true do
			if pos > #s then error("unexpected EOF in string") end
			local c = s:sub(pos, pos)
			pos = pos + 1
			if c == '"' then break
			elseif c == '\\' then
				local c = s:sub(pos, pos)
				pos = pos + 1
				if c == 'u' then
					error("TODO: \\u")
				elseif c == 'n' then os = os .. '\n'
				elseif c == 'r' then os = os .. '\r'
				elseif c == 't' then os = os .. '\t'
				elseif c == 'b' then os = os .. '\b'
				else
					os = os .. c
				end
				
			else
				os = os .. c
			end
		end
		pos = skipws(s, pos)
		return os, pos

	elseif c == 'f' and s:sub(pos, pos+4) == "false" then
		pos = skipws(s, pos + 5)
		return false, pos

	elseif c == 't' and s:sub(pos, pos+3) == "true" then
		pos = skipws(s, pos + 4)
		return true, pos

	elseif c == 'n' and s:sub(pos, pos+3) == "null" then
		pos = skipws(s, pos + 4)
		return nil, pos
	
	elseif (c:byte() >= 0x30 and c:byte() <= 0x39) or c == '-' then
		local isneg = false
		if c == '-' then
			isneg = true
			pos = pos + 1
			c = s:sub(pos, pos)
		end

		local v = 0
		if c == '0' then
			pos = pos + 1
			c = s:sub(pos, pos)

		elseif (c:byte() >= 0x31 and c:byte() <= 0x39) then
			while pos <= #s do
				local b = c:byte()
				if b >= 0x30 and b <= 0x39 then
					v = (v*10) + (b-0x30)
					pos = pos + 1
					c = s:sub(pos, pos)
				else break
				end
			end

		else error("expected digit to start number or after -")
		end

		if c == '.' then
			pos = pos + 1
			c = s:sub(pos, pos)
			local smul = 0.1
			local b = c:byte()
			if not (b >= 0x30 and b <= 0x39) then
				error("expected digit after .")
			end
			while pos <= #s do
				local b = s:byte(pos)
				if b >= 0x30 and b <= 0x39 then
					v = v + smul*(b-0x30)
					pos = pos + 1
					c = s:sub(pos, pos)
				else break
				end
			end
		end

		if c == 'e' or c == 'E' then
			error("TODO: exponent format for numbers")
		end

		if isneg then v = -v end
		--print(v, s:sub(pos,pos))
		pos = skipws(s, pos)
		--print(v, s:sub(pos,pos))
		return v, pos

	else
		print(c)
		error("unhandled thing!")
	end
end

function json_escape_string(s)
	s = s:gsub("\n", "\\n")
	s = s:gsub("\r", "\\r")
	s = s:gsub("\t", "\\t")
	s = s:gsub("\b", "\\b")
	s = s:gsub("\"", "\\\"")
	return s
end

function json_encode(l)
	if type(l) == "table" then
		if #l > 0 then
			local s = ""
			local k,v
			for k,v in ipairs(l) do
				s = s .. "," .. json_encode(v)
			end
			return "["..s:sub(2).."]"

		else
			local s = ""
			local k,v
			for k,v in pairs(l) do
				s = s .. "," .. json_encode(k) .. ":" .. json_encode(v)
			end
			return "{"..s:sub(2).."}"

		end
	elseif type(l) == "number" then
		return l
	elseif type(l) == "string" then
		return '"' .. json_escape_string(l) .. '"'
	elseif l == true then return "true"
	elseif l == false then return "false"
	elseif l == nil then return "null"
	else
		error("unhandled type for json_encode")
	end

end

