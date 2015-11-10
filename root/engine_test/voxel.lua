-- C code port
-- This will probably be gutted out before being ported back to C

function fill_voxygen_subchunk(voxygen_buf, layer, sx, sy, sz, c)
	local lsize = 128>>layer
	assert(layer >= 0)
	assert(layer <= 4)
	assert((sx>>layer) >= 0)
	assert((sy>>layer) >= 0)
	assert((sz>>layer) >= 0)
	assert((sx>>layer) < (128>>layer))
	assert((sy>>layer) < (128>>layer))
	assert((sz>>layer) < (128>>layer))
	assert((sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer)) >= 0)
	assert((sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer)) < (128>>layer)*(128>>layer)*(128>>layer))
	assert((c & 0x80) == 0)
	--if(layer == 0) c &= ~0x80
	voxygen_buf[layer+1][1+(sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer))] = c

	if(layer > 0) then
		layer = layer - 1
		assert((c & 0x80) == 0)
		--c &= ~0x80

		c = c | 0x40
		--[[
		if((c & 0x40) == 0) then
			c = 0x40 + (layer+1)
		end
		]]

		local l0 = 0
		local l1 = 1<<layer

		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l0, sz+l0, c)
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l0, sz+l0, c)
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l0, sz+l1, c)
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l0, sz+l1, c)
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l1, sz+l0, c)
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l1, sz+l0, c)
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l1, sz+l1, c)
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l1, sz+l1, c)
	end
end

function decode_voxygen_subchunk(voxygen_buf, fp, layer, sx, sy, sz)
	local c = fp:getc(1)
	assert(c >= 0)
	assert(c <= 0xFF) -- juuuuust in case your libc sucks (this IS being overcautious though)
	assert((c & 0x40) == 0)

	if((c & 0x80) ~= 0) then
		assert(layer > 0)

		-- Write
		local lsize = 128>>layer
		voxygen_buf[layer+1][1+(sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer))] = c

		-- Descend
		layer = layer - 1
		local l0 = 0
		local l1 = 1<<layer
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l0, sz+l0)
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l1, sz+l0)
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l0, sz+l0)
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l1, sz+l0)
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l0, sz+l1)
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l1, sz+l1)
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l0, sz+l1)
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l1, sz+l1)

	else
		-- Fill
		fill_voxygen_subchunk(voxygen_buf, layer, sx, sy, sz, c)
	end
end

function decode_voxygen_chunk(voxygen_buf, fp)
	local sx, sy, sz

	for sz=0,128-1,16 do
	for sx=0,128-1,16 do
	for sy=0,128-1,16 do
		decode_voxygen_subchunk(voxygen_buf, fp, 4, sx, sy, sz)
	end
	end
	end
end

function voxygen_load_repeated_chunk(fname)
	misc.gl_error()

	-- TODO: load more than a chunk
	-- Layer 1: 128^3 chunks in a [z][x]
	-- Layer 2: 32^3 outer layers in a 4^3 arrangement [z][x][y]
	-- Layer 3: Descend the damn layers
	-- in this engine we rearrange it to [y][z][x]
	local cx, cz
	local cy = 0
	local sx, sy, sz
	local voxygen_buf

	local fdata = bin_load(fname)

	if voxel.decode_chunk then
		voxygen_buf = voxel.decode_chunk(fdata, 5, 7)
	else
		print("Allocating voxel arrays")
		voxygen_buf = {}
		voxygen_buf[1] = {}
		voxygen_buf[2] = {}
		voxygen_buf[3] = {}
		voxygen_buf[4] = {}
		voxygen_buf[5] = {}

		print("Decoding voxel data")
		local fp = {
			fdata = fdata,
			fpos = 1,
			getc = function(this)
				if this.fpos > #this.fdata then return nil end
				local ret = this.fdata:sub(this.fpos, this.fpos)
				this.fpos = this.fpos + 1
				return string.byte(ret)
			end,
			close = function() end,
		}
		decode_voxygen_chunk(voxygen_buf, fp)
	end

	print("Uploading voxel data")
	if voxel.upload_chunk_repeated then
		voxel.upload_chunk_repeated(tex_ray_vox, voxygen_buf, 5, 7, 9)
	else
		local layer
		for layer=0,4,1 do
			local lsize = 128>>layer
			local ly = 128*2-(lsize*2)
			for sz=0,512-1,lsize do
			for sx=0,512-1,lsize do
			for sy=0,lsize-1,lsize do
				texture.load_sub(tex_ray_vox, "3", 0, sx, sz, sy + ly, lsize, lsize, lsize, "1ub", voxygen_buf[layer+1])
				--print(string.format("%i - %i %i %i %i", misc.gl_error(), sx, sy, sz, ly))
			end
			end
			end
		end
	end
	print("Freeing voxel data")

	voxygen_buf = {}

	local err = misc.gl_error()
	print(string.format("tex_vox %i", err))
	assert(err == 0)
end


