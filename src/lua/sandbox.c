#include "common.h"

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
		// TODO: work out what to do with errors + dispose of this bloody VM
		// (chances are we'll have to do lua_newthread then SOMEHOW remove the thread)

		const char *code = luaL_checkstring(L, 2);
		Lnew = init_lua_vm(L, vmtyp, NULL, 0);

		luaL_loadstring(Lnew, code);
		lua_pushvalue(Lnew, -1); // back up function (so we can steal the environment)
		lua_pcall(Lnew, 0, 0, 0);
		lua_getupvalue(Lnew, -1, 1);
		lua_xmove(Lnew, L, 1);
		lua_remove(L, -2);
		lua_gc(Lnew, LUA_GCCOLLECT, 0);
		return 1;

	} else if(vmtyp == VM_PLUGIN) {
		const char *subroot = luaL_checkstring(L, 2);
		char *newroot = fs_dir_extend(es->root_dir, subroot);
		assert(newroot != NULL);
		printf("PLUGIN \"%s\"\n", newroot);
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
	if(luaL_newmetatable(L, "VMRef") != 0)
	{
		// Fill in metatable
		// FIXME: __gc
		// TODO!
		//lua_push(L, ); lua_setfield(L, -2, "");
		lua_pushstring(L, "NOPE"); lua_setfield(L, -2, "__metatable");
	}
	lua_setmetatable(L, -2);

	return 1;
}

void lbind_setup_sandbox(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_sandbox_new); lua_setfield(L, -2, "new");
	lua_setglobal(L, "sandbox");
}

