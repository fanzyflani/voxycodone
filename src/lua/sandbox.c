#include "common.h"

static int ltyp_gc_vmref(lua_State *L)
{
	// FIXME: prevent lua from spewing an error in the __gc hook, that's just dangerous
	lua_State **pLtarget = luaL_checkudata(L, 1, "VMRef");
	lua_State *Ltarget = *pLtarget;
	struct vc_extraspace *estarget = *(struct vc_extraspace **)(lua_getextraspace(Ltarget));
	estarget->refcount--;
	printf("VMRef %p lost, from %p - refcount = %i\n", Ltarget, L, estarget->refcount);

	assert(estarget->refcount >= 0);
	if(estarget->refcount <= 0)
	{
		printf("Freeing VM!\n");
		lua_close(Ltarget);
	}
}

static void copy_between_states(lua_State *L, lua_State *Ltarget, int recmax)
{
	// Check if valid type
	int vt = lua_type(L, -1);
	if(vt == LUA_TNIL)
		lua_pushnil(Ltarget);
	else if(vt == LUA_TBOOLEAN)
		lua_pushboolean(Ltarget, lua_toboolean(L, -1));
	else if(vt == LUA_TSTRING)
		lua_pushstring(Ltarget, lua_tostring(L, -1));
	else if(vt == LUA_TNUMBER && lua_isinteger(L, -1))
		// FIXME: needs to check the subtype correctly
		lua_pushinteger(Ltarget, lua_tointeger(L, -1));
	else if(vt == LUA_TNUMBER && !lua_isinteger(L, -1))
		lua_pushnumber(Ltarget, lua_tonumber(L, -1));
	else if(vt == LUA_TTABLE && recmax > 0)
	{
		lua_newtable(Ltarget);

		// move all the things
		lua_pushnil(L);
		// -2 = table, -1 = lookup key
		while(lua_next(L, -2) != 0)
		{
			//printf("PUSH: %s %s\n", lua_tostring(L, -2), lua_typename(L, lua_type(L, -1)));
			// L: -3 = table, -2 = lookup key, -1 = value
			// Ltarget: -1 = table
			lua_pushvalue(L, -2);
			copy_between_states(L, Ltarget, recmax-1);
			// Ltarget: -2 = table, -1 = key
			copy_between_states(L, Ltarget, recmax-1);
			// Ltarget: -3 = table, -2 = key, -1 = value
			// L: -2 = table, -1 = lookup key
			//printf("result: %s\n", lua_typename(Ltarget, lua_type(Ltarget, -1)));
			lua_rawset(Ltarget, -3);
			// Ltarget: -1 = table
		}
	} else {
		// otherwise just ignore it
		lua_pushnil(Ltarget);
	}

	// Remove value
	lua_pop(L, 1);
}

static int lbind_sandbox_new(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected at least 1 argument to sandbox.new");

	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));

	if(es->vmtyp == VM_BLIND) return luaL_error(L, "EDOOFUS: should not be able to spawn sandboxes from blind!");

	const char *vmtyp_str = luaL_checkstring(L, 1);

	enum vc_vm vmtyp = VM_TYPE_COUNT;

	if(0) {}
	else if(!strcmp(vmtyp_str, "blind")) vmtyp = VM_BLIND;
	else if(!strcmp(vmtyp_str, "client")) vmtyp = VM_CLIENT;
	else if(!strcmp(vmtyp_str, "server")) vmtyp = VM_SERVER;
	else if(!strcmp(vmtyp_str, "plugin")) vmtyp = VM_PLUGIN;
	else {
		return luaL_error(L, "invalid VM type");
	}

	// Validate
	if(0) {}
	else if(vmtyp == VM_BLIND) {}
	else if(es->vmtyp == VM_SYSTEM && vmtyp != VM_SYSTEM) {}
	else if(vmtyp == VM_PLUGIN && es->vmtyp != VM_PLUGIN) {}
	else if(vmtyp == VM_SERVER && es->vmtyp == VM_SYSTEM) {}
	else if(vmtyp == VM_CLIENT && (es->vmtyp == VM_SYSTEM || es->vmtyp == VM_SYSTEM)) {}
	else {
		return luaL_error(L, "this VM cannot create the given VM type");
	}

	// Create VM
	lua_State *Lnew = NULL;

	// Check VM type
	if(vmtyp == VM_BLIND)
	{
		// Run immediately
		// TODO: work out what to do with errors

		const char *code = luaL_checkstring(L, 2);
		Lnew = init_lua_vm(L, vmtyp, NULL, 0);

		luaL_loadstring(Lnew, code);
		lua_pushvalue(Lnew, -1); // back up function (so we can steal the environment)
		lua_pcall(Lnew, 0, 0, 0);
		lua_getupvalue(Lnew, -1, 1);

		// move everything
		copy_between_states(Lnew, L, 7);

		// clean up
		lua_remove(L, -2);
		lua_close(Lnew);
		return 1;

	} else if(vmtyp == VM_PLUGIN) {
		const char *subroot = luaL_checkstring(L, 2);
		char *newroot = fs_dir_extend(es->root_dir, subroot);
		assert(newroot != NULL);
		//printf("PLUGIN \"%s\"\n", newroot);
		Lnew = init_lua_vm(L, vmtyp, newroot, 0);
		free(newroot);

	} else {
		return luaL_error(L, "EDOOFUS: invalid or unhandled VM type");
	}

	// OK, not a blind VM.

	// Call main.lua
	lua_getglobal(Lnew, "dofile");
	lua_pushstring(Lnew, "main.lua");
	lua_call(Lnew, 1, 0);

	// Wrap VM
	lua_State **pL = lua_newuserdata(L, sizeof(lua_State *));
	*pL = Lnew;
	struct vc_extraspace *esnew = *(struct vc_extraspace **)(lua_getextraspace(Lnew));
	esnew->pLself = pL;
	esnew->refcount++;

	if(luaL_newmetatable(L, "VMRef") != 0)
	{
		// Fill in metatable
		lua_pushcfunction(L, ltyp_gc_vmref); lua_setfield(L, -2, "__gc");
		lua_pushstring(L, "NOPE"); lua_setfield(L, -2, "__metatable");
	}
	lua_setmetatable(L, -2);

	return 1;
}

static int lbind_sandbox_send(lua_State *L)
{
	int i;
	int top = lua_gettop(L);

	if(top < 1)
		return luaL_error(L, "expected at least 1 argument to sandbox.send");

	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));

	// Get target
	lua_State *Ltarget;
	if(lua_isboolean(L, 1) && lua_toboolean(L, 1))
	{
		Ltarget = es->Lparent;
		if(Ltarget == NULL)
			return luaL_error(L, "sandbox has no parent");

	} else {
		lua_State **pLtarget = luaL_checkudata(L, 1, "VMRef");
		Ltarget = *pLtarget;
	}

	struct vc_extraspace *estarget = *(struct vc_extraspace **)(lua_getextraspace(Ltarget));

	if(es->vmtyp == VM_BLIND) return luaL_error(L, "EDOOFUS: should not be able to touch sandboxes from blind!");
	if(estarget->vmtyp == VM_BLIND) return luaL_error(L, "EDOOFUS: should not be able to touch blind sandboxes!");

	// Build mailbox entry
	lua_getglobal(Ltarget, "sandbox");
	lua_getfield(Ltarget, -1, "mbox");
	lua_createtable(Ltarget, top, 0);
	lua_len(Ltarget, -2); // XXX: do we use raw?
	int len = lua_tointeger(Ltarget, -1);
	lua_pop(Ltarget, 1);

	{
		if(L == estarget->Lparent)
		{
			lua_pushboolean(Ltarget, true);

		} else {
			lua_State **pL = lua_newuserdata(Ltarget, sizeof(lua_State *));
			*pL = L;
			luaL_getmetatable(Ltarget, "VMRef");
			lua_setmetatable(Ltarget, -2);
			es->refcount++;
		}

		lua_seti(Ltarget, -2, 1);
	}

	for(i = 2; i <= top; i++)
	{
		// Check if valid type
		int vt = lua_type(L, i);
		if(vt == LUA_TNIL)
			lua_pushnil(Ltarget);
		else if(vt == LUA_TBOOLEAN)
			lua_pushboolean(Ltarget, lua_toboolean(L, i));
		else if(vt == LUA_TSTRING)
			lua_pushstring(Ltarget, lua_tostring(L, i));
		else if(vt == LUA_TNUMBER && lua_isinteger(L, i))
			// FIXME: needs to check the subtype correctly
			lua_pushinteger(Ltarget, lua_tointeger(L, i));
		else if(vt == LUA_TNUMBER && !lua_isinteger(L, i))
			lua_pushnumber(Ltarget, lua_tonumber(L, i));
		else
			return luaL_error(L,
				"invalid argument type for message argument #%d to sandbox.send",
				i-1);

		lua_seti(Ltarget, -2, i);
	}

	// Add to mailbox
	lua_seti(Ltarget, -2, len+1);
	lua_pop(Ltarget, 2);

	// Return!
	return 0;
}

static int lbind_sandbox_poll(lua_State *L)
{
	int i;
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to sandbox.poll");

	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));

	// Get target
	lua_State **pLtarget = luaL_checkudata(L, 1, "VMRef");
	lua_State *Ltarget = *pLtarget;

	struct vc_extraspace *estarget = *(struct vc_extraspace **)(lua_getextraspace(Ltarget));

	if(es->vmtyp == VM_BLIND) return luaL_error(L, "EDOOFUS: should not be able to touch sandboxes from blind!");
	if(estarget->vmtyp == VM_BLIND) return luaL_error(L, "EDOOFUS: should not be able to touch blind sandboxes!");

	// Set FBO
	// FIXME: need to reset textures on context switches
	if(estarget->fbo != -1)
		glBindFramebuffer(GL_FRAMEBUFFER, estarget->fbo);

	// Call hook
	lua_getglobal(Ltarget, "hook_poll");
	lua_call(Ltarget, 0, 0);

	// Reset FBO
	if(es->fbo != -1)
		glBindFramebuffer(GL_FRAMEBUFFER, es->fbo);

	// Return!
	return 0;
}

static int lbind_sandbox_fbo_get_tex(lua_State *L)
{
	int i;
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to sandbox.fbo_get_tex");

	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));

	// Get target
	lua_State **pLtarget = luaL_checkudata(L, 1, "VMRef");
	lua_State *Ltarget = *pLtarget;

	struct vc_extraspace *estarget = *(struct vc_extraspace **)(lua_getextraspace(Ltarget));

	if(es->vmtyp == VM_BLIND) return luaL_error(L, "EDOOFUS: should not be able to touch sandboxes from blind!");
	if(estarget->vmtyp == VM_BLIND) return luaL_error(L, "EDOOFUS: should not be able to touch blind sandboxes!");

	// Get FBO texture
	if(estarget->fbo == 0)
		lua_pushnil(L);
	else if(estarget->fbo != -1)
		lua_pushinteger(L, estarget->fbo_ctex);
	else
		lua_pushnil(L);

	// Return!
	return 1;
}

void lbind_setup_sandbox(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_sandbox_new); lua_setfield(L, -2, "new");
	lua_pushcfunction(L, lbind_sandbox_send); lua_setfield(L, -2, "send");
	lua_pushcfunction(L, lbind_sandbox_poll); lua_setfield(L, -2, "poll");
	lua_pushcfunction(L, lbind_sandbox_fbo_get_tex); lua_setfield(L, -2, "fbo_get_tex");
	lua_newtable(L); lua_setfield(L, -2, "mbox");
	lua_setglobal(L, "sandbox");
}

