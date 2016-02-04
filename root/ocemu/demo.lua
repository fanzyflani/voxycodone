time_base = nil
local function wait(d)
	time_base = time_base or computer.uptime()
	assert(d >= 0.0)
	os.sleep(d)
end

do
--
--
--
local W, H = gpu.getResolution()
local FADETAB = { " ","░","▒","▓","█" }

local fstr = bin_load("rawcga.bin")
gpu.set(2, 2, "HELLO WORLD! ☻")

--
--
--
end

wait(0.1)

