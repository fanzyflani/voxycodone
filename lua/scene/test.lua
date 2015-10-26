require("lua/objects")

-- DEFINITIONS
m_chequer_bw = mat_chequer {
	c0 = {0.9, 0.9, 0.9},
	c1 = {0.1, 0.1, 0.1},
}

--[[
obj_csg_subtract {
	main = obj_plane {
		dir = "+y",
		pos = {0, -2, 0},
		mat = m_chequer_bw,
	},

	cutters = {
		obj_sphere {
			pos = {0, -2, 0},
			rad = 1.0,
			mat = mat_solid {
				c0 = {0.9, 0.3, 0.9},
			},
		},
	},
}
]]

obj_plane {
	dir = "+y",
	pos = {0, -2, 0},
	mat = m_chequer_bw,
}

obj_plane {
	dir = "+z",
	pos = {0, 0, -20},
	mat = mat_solid { c0 = {1.0, 1.0, 0.0}, },
}

local k, v
print("")
for k, v in pairs(OBJLIST) do
	print("processing", k)
	print("-----")
	process_src(v)
	print("-----")
	process_src(v[2].mat)
	print("-----\n")
end

