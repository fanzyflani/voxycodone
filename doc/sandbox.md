WARNING: WIP.

The sandbox models will need a bit of explaining.

System 
------

* Boot mode
* Root directory is `root/` and is read/write
* Drawable on regular executable; non-drawable on dedicated server
* Can spawn Server, Client, Plugin, Blind

Server
------

* Root directory is a subset of its parent's
* Writable directory is `${ROOT}/save/`
* Message link to remote clients
* Can spawn Plugin, Blind

Client
------

* Needs a remote server to connect to
* Root directory is a virtual network disk
* Server provides the bootloader and all the files
* Drawable to FBO
* Can spawn Blind

Plugin
------

* Root directory is a subset of its parent's
* Drawable to FBO
* Can spawn Blind
* Basically Client but with a physical root dir rather than a network dir, and without networking

Blind
-----

* Extremely limited sandbox that can be spawned by the other sandbox models
* No file access
* Builtins provided:
  * math
  * string
  * table
* Parent has direct (possibly filtered?) access to environment

-------------------------------------------------------------------------------

General rules:

* File access is provided via `bin_load` and `bin_save` functions
  * `io.*` is an emulation layer atop these two functions:
    * Read-only: Call `bin_load`, supply read-only buffer
    * Write-only: Supply RW buffer, on close or GC call `bin_save`
    * Read-write: `bin_load`, supply RW buffer, on close or GC `bin_save`
    * May change it so if GC happens on writable file, crash cleanly

-------------------------------------------------------------------------------

MORE TO BE WRITTEN.

[]: # ( vim: set syntax=markdown : )

