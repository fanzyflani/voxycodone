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
	lua_State *Lnew = init_lua_vm(L, vmtyp, NULL, 0);

	// Check if blind
	if(vmtyp == VM_BLIND)
	{
		// Run immediately
		// TODO: work out what to do with errors + dispose of this bloody VM
		const char *code = lua_tostring(L, 2);
		luaL_loadstring(Lnew, code);
		lua_pushvalue(Lnew, -1); // back up function
		lua_pcall(Lnew, 0, 0, 0);
		lua_getupvalue(Lnew, -1, 1);
		lua_xmove(Lnew, L, 1);
		lua_remove(L, -2);
		return 1;
	}

	assert(!"We haven't done this yet");
	abort();

	// FIXME: this actually needs to be written

	// Wrap VM
	if(luaL_newmetatable(L, "VMRef") != 0)
	{
		// Fill in metatable
		// FIXME: __gc
		// TODO!
		//lua_push(L, ); lua_setfield(L, -2);
	}
	lua_State **pL = lua_newuserdata(L, sizeof(lua_State *));
	*pL = Lnew;
	lua_setmetatable(L, -2);

	return 0;
}

void lbind_setup_sandbox(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_sandbox_new); lua_setfield(L, -2, "new");
	lua_setglobal(L, "sandbox");
}

