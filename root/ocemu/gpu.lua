--[[
official docs denote these max call values for each tier:
	+------+---+---+----+
	|      | 1 | 2 | 3  |
	+------+---+---+----+
	| copy | 1 | 2 | 4  |
	| fill | 1 | 4 | 8  |
	| set  | 4 | 8 | 16 |
	| bg   | 2 | 4 | 8  |
	| fg   | 2 | 4 | 8  |
	+------+---+---+----+
]]

local function utf8_to_cp437(s)
	local i = 1
	local ret = ""
	while i <= #s do
		local b = s:byte(i)
		local v
		if (b & 0x80) == 0 then
			assert(i+1 <= #s+1)
			v = b
			i = i + 1
		elseif (b & 0xE0) == 0xC0 then
			assert(i+2 <= #s+1)
			v = b & 0x1F
			i = i + 1
			b = s:byte(i)
			assert((b & 0xC0) == 0x80)
			v = v << 6
			v = v | (b & 0x3F)
			i = i + 1
		elseif (b & 0xF0) == 0xE0 then
			assert(i+3 <= #s+1)
			v = b & 0x1F
			i = i + 1
			b = s:byte(i)
			assert((b & 0xC0) == 0x80)
			v = v << 6
			v = v | (b & 0x3F)
			i = i + 1
			b = s:byte(i)
			assert((b & 0xC0) == 0x80)
			v = v << 6
			v = v | (b & 0x3F)
			i = i + 1
		else
			error("could not decode char")
		end
		ret = ret .. string.char(UNI_TO_CP437[v] or 0xFE)
		--ret = ret .. string.char(v)
	end

	return ret
end

gpu = {}

local gpu_fg, gpu_bg = 15, 0
local wait_buffer = 0.0
local wait_quant = 0.0
local lim_copy = 0
local lim_fill = 0
local lim_set = 0
local lim_fg = 0
local lim_bg = 0
local gpu_needs_flush = false

local function reset_rate_limits()
	-- assuming Tier 3 and not what asie mentioned
	if true then
		lim_copy = 4*16
		lim_fill = 8*16
		lim_set = 16*16
		lim_fg = 8*16
		lim_bg = 8*16
	else
		lim_copy = 4
		lim_fill = 8
		lim_set = 16
		lim_fg = 8
		lim_bg = 8
	end
end
reset_rate_limits()

local function update_screen()
	gpu_needs_flush = false
	texture.load_sub(tex_chars, "2", 0, 0, 0, virtual_w, virtual_h, "3ub", virtual_data)
	texture.load_sub(tex_palette, "1", 0, 0, 256, "3nb", virtual_palette)
end

function wait(delay)
	if gpu_needs_flush then
		reset_rate_limits()
		update_screen()
	end
	assert(delay >= 0.05)
	wait_quant = wait_quant + delay
	local reduce = math.floor(wait_quant/0.05)*0.05
	wait_buffer = wait_buffer + reduce
	wait_quant = wait_quant - reduce
	while wait_buffer > 0.0 do
		local cur, del = coroutine.yield()
		wait_buffer = wait_buffer - del
	end
end

local function flush_rate_limits()
	reset_rate_limits()
	update_screen()
	wait(0.05)
end

function gpu.set(x, y, value)
	local s = utf8_to_cp437(value)
	assert(x >= 1)
	assert(y >= 1)
	assert(x+#s-1 <= gpu_res_w)
	assert(y <= gpu_res_h)

	if lim_set <= 0 then
		flush_rate_limits()
	end
	lim_set = lim_set - 1

	local offs = virtual_w*y + x - 1
	local i
	for i=1,#s do
		virtual_data[3*(offs+i)+1] = s:byte(i)
		virtual_data[3*(offs+i)+2] = gpu_fg
		virtual_data[3*(offs+i)+3] = gpu_bg
	end

	gpu_needs_flush = true
end

function gpu.fill(x, y, width, height, char)
	assert(width >= 1)
	assert(height >= 1)
	assert(x >= 1)
	assert(y >= 1)
	assert(x+width-1 <= gpu_res_w)
	assert(y+height-1 <= gpu_res_h)
	local s = utf8_to_cp437(char)
	assert(#s == 1)

	if lim_fill <= 0 then
		flush_rate_limits()
	end
	lim_fill = lim_fill - 1

	local ch = s:byte()
	local u,v
	for v=0,height-1 do
		local offs = virtual_w*(y+v) + x - 1
		for u=0,width-1 do
			virtual_data[3*(offs+u)+1] = ch
			virtual_data[3*(offs+u)+2] = gpu_fg
			virtual_data[3*(offs+u)+3] = gpu_bg
		end
	end

	gpu_needs_flush = true
end

function gpu.copy(x, y, width, height, tx, ty)
	assert(width >= 1)
	assert(height >= 1)
	assert(x >= 1)
	assert(y >= 1)
	assert(x+width-1 <= gpu_res_w)
	assert(y+height-1 <= gpu_res_h)
	assert(x+tx >= 1)
	assert(y+ty >= 1)
	assert(x+tx+width-1 <= gpu_res_w)
	assert(y+ty+height-1 <= gpu_res_h)

	if lim_copy <= 0 then
		flush_rate_limits()
	end
	lim_copy = lim_copy - 1

	local u,v
	local doffs = (virtual_w*ty + tx)
	if doffs > 0 then
		for v=height-1,0,-1 do
			local offs = virtual_w*(y+v) + x - 1
			for u=width-1,0,-1 do
				virtual_data[3*(offs+doffs+u)+1] = virtual_data[3*(offs+u)+1]
				virtual_data[3*(offs+doffs+u)+2] = virtual_data[3*(offs+u)+2]
				virtual_data[3*(offs+doffs+u)+3] = virtual_data[3*(offs+u)+3]
			end
		end
	else
		for v=0,height-1 do
			local offs = virtual_w*(y+v) + x - 1
			for u=0,width-1 do
				virtual_data[3*(offs+doffs+u)+1] = virtual_data[3*(offs+u)+1]
				virtual_data[3*(offs+doffs+u)+2] = virtual_data[3*(offs+u)+2]
				virtual_data[3*(offs+doffs+u)+3] = virtual_data[3*(offs+u)+3]
			end
		end
	end

	gpu_needs_flush = true
end

local function convert_color(color, isPaletteIndex)
	if isPaletteIndex then
		assert(color >= 0 and color < 16)
		return color
	else
		assert(color >= 0x000000 and color <= 0xFFFFFF)
		local r = (color>>16) & 0xFF
		local g = (color>>8) & 0xFF
		local b = (color>>0) & 0xFF
		r = math.floor(math.min(6-1, ((r*2+1)*6)//(255*2)))
		g = math.floor(math.min(8-1, ((g*2+1)*8)//(255*2)))
		b = math.floor(math.min(5-1, ((b*2+1)*5)//(255*2)))

		local ret = b + 5*(g + 8*r) + 16
		assert(ret >= 16 and ret < 256)
		print(ret)
		return ret
	end
end

function gpu.setForeground(color, isPaletteIndex)
	if lim_fg <= 0 then
		flush_rate_limits()
	end
	lim_fg = lim_fg - 1

	local rcol = convert_color(color, isPaletteIndex)

	gpu_fg = rcol

	if rcol < 16 then
		return rcol
	else
		return nil
	end
	
end

function gpu.setBackground(color, isPaletteIndex)
	if lim_bg <= 0 then
		flush_rate_limits()
	end
	lim_bg = lim_bg - 1

	local rcol = convert_color(color, isPaletteIndex)

	gpu_bg = rcol

	if rcol < 16 then
		return rcol
	else
		return nil
	end
	
end

function gpu.setPaletteColor(index, value)
	assert(index >= 0 and index < 16)
	assert(value >= 0x000000 and value <= 0xFFFFFF)

	local r = (value>>16)&0xFF
	local g = (value>>8)&0xFF
	local b = (value>>0)&0xFF
	virtual_palette[3*index+1] = r
	virtual_palette[3*index+2] = g
	virtual_palette[3*index+3] = b

	gpu_needs_flush = true
end

function gpu.getResolution()
	return gpu_res_w, gpu_res_h
end

