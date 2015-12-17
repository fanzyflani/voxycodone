B64TENC = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
B64TDEC = {}

do
	local i
	for i=1,64 do
		B64TDEC[B64TENC:sub(i,i)] = i-1
	end
	B64TDEC["="] = 0
end

function base64_decode(s)
	local os = ""
	local i

	for i=1,#s,4 do
		local sb = s:sub(i, i+4-1)
		--print(sb)
		local j
		local v = 0
		for j=1,4 do
			--print(B64TDEC[sb:sub(j,j)])
			v = v + (B64TDEC[sb:sub(j,j)]<<((4-j)*6))
		end
		if sb:sub(3,3) ~= "=" then
			if sb:sub(4,4) ~= "=" then
				os = os .. string.char((v>>16)&0xFF)
			end
			os = os .. string.char((v>>8)&0xFF)
		end
		os = os .. string.char((v>>0)&0xFF)
	end
	--print(os:byte(1), #os % 3)
	return os
end
