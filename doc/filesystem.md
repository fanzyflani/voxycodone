WARNING: WIP. Also completely unimplemented at this point.

IGNORE WHAT WAS WRITTEN ABOUT EACH PATH HAVING DIFFERENT MOUNTED FILESYSTEMS.

This will be covered on the Lua side.

There are two different types of root filesystems:

* physical directory
* network fetch

The root filesystem for a sandbox will be one of those.

`bin_save` will only be provided to the System and Server sandboxes.
Use the appropriate messaging API to shove stuff into storage.
(TODO: make said messaging API)

`dofile` depends on the global `loadfile` which depends on the global `bin_load`.
This means that you can make `bin_load` point to something else,
and `dofile` and `loadfile` will end up using that instead.

----

Valid filename characters:

	-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_abcdefghijklmnopqrstuvwxyz

If you abuse case-insensitivity I reserve the right to punch you. In the face. With a truck.

Also I legitimately can't remember why I added [] to the list.
This is the same list used in Iceball, and I conceived this list about 3 years ago.

Valid path separators:

	/

These will be strictly checked.

----

The general layout:

* `root/`
  * `main.lua`: Initial System sandbox bootloader
  * `config.lua`: User configuration (Blind)
  * `menu/`: Menu files (run within the System sandbox)
  * `lib/`: Libraries that can be provided if necessary (?)
  * `${GAMENAME}/`
    * `game_package.lua`: Metadata for a game (Blind)
    * `common`/
      * `main.lua`: Bootloader (Client)
    * `main.lua`: Bootloader (Server)
  * `${PLUGNAME}/`
    * `plug_package.lua`: Metadata for a plugin (Blind)
* `dlcache/`
  * `${HASH}-${file_name}.zip`: Hashed, cached file.

Game metadata has the following format:

TODO

Plugin metadata has yet to be determined

Server hook:

	function hook_file(fname)
		if file_valid_write_this_yourself(fname) then
			return bin_load(remap_file_write_this_yourself(fname))
		else
			return nil
		end
	end

Connect hook:

	function hook_connect(conn_id, sockfd, address, enet_data)
		if connection_valid_write_this_yourself() then
			return true, bootloader_script_string
		else
			return false, "Kick reason goes here"
		end
	end

[]: # ( vim: set syntax=markdown : )

