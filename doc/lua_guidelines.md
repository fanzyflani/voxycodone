Lua coding guidelines:

*Assumptions around Lua data types:*

* `lua_Number` is double-precision floating point.
* `lua_Integer` is a 64-bit signed integer.
* `lua_Unsigned` is a 64-bit unsigned integer.

If these are not true, recompile Lua.

*Rules for string.pack/unpack:*

Do NOT use ANY "native" stuff (except for float and double). ESPECIALLY NOT ANYTHING IMPLICIT.

That is, if your format string doesn't begin in ">" or "<", IT'S PROBABLY WRONG. DO NOT ASSUME THAT PEOPLE USE YOUR ENDIANNESS. Some people use the utter shite that is big endian.

For actual elements, only use explicit formats. b/B are fine. s/S are NOT. If you use l/L, GO DIE IN A FIRE. (32-bit and 64-bit systems have different lengths for "long".)

If you *do* use the native types, you *MUST* probe the lengths beforehand. Or you could just not use the native types because that's probably not going to actually improve performance.

The *only* native types you can use are for float and double. Please use these instead of `lua_Number`. If it turns out that they are not 32 bits and 64 bits respectively, please strangle the person responsible for making a mess of your C compiler.

USE CORRECT SIGNING. I know for a fact that ARM platforms (read: the ARMv6 raspi does this) will actually clamp a floating point number to fit into either a signed or an unsigned integer.

*:*

Yeah OK, there's probably more things I need to point out.

[]: # ( vim: set syntax=markdown : )

