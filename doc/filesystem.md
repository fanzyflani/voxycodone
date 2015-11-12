WARNING: WIP. Also completely unimplemented at this point.

Ultimately, each path can potentially be provided by several different mounted "filesystems".

The filesystems available are:

* physical directory
* network fetch
* .zip file

The root filesystem for a sandbox will be one of those.

* Filesystems can go in front of or behind other filesystems in terms of priority.
* Filesystems can be mounted at different directories aside from the root directory.
* The files "behind" a filesystem can either be merged or obscured. This is useful for when you have a different mount point.
* It's probably a good idea to have the root filesystem in front of (higher priority than) any .zip filesystems.

The general layout:

* `root/`
  * `main.lua`: Initial System sandbox bootloader
  * `config.lua`: User configuration (Blind)
  * `menu/`: Menu files (run within the System sandbox)
  * `lib/`: Libraries that can be provided if necessary (?)
  * `${GAMENAME}/`
    * `game_package.lua`: Metadata for a game (Blind)
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

