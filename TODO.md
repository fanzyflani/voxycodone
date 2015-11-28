
Cleanup
-------

This really should happen before the other things.

* [x] Port src/voxel.c to Lua (RESOLUTION: leave src/voxel.c intact)
* [x] Split src/lbind.c into different files
* [x] Update shader.new()
* [ ] Port the main loop to Lua
* [ ] Move stuff into place in preparation for sandbox system
* [x] Make API docs

API
---

* [ ] Expose more stuff in libs:
  * [ ] 1D textures
  * [ ] Cubemaps
  * [x] Fill in all dims for these (TODOs in brackets):
    * [x] `texture.load_sub` (1D)
    * [x] `texture.new` (1D)
  * [x] Support more texture formats:
    * [x] `GL_FLOAT`
    * [x] `GL_BYTE`
    * [x] `GL_SHORT`
    * [x] `GL_INT`
    * [x] `GL_UNSIGNED_BYTE`
    * [x] `GL_UNSIGNED_SHORT`
    * [x] `GL_UNSIGNED_INT`
  * [ ] `matrix.*`
  * [ ] `shader.uniform_*`

Game engine
-----------

* [ ] Physics

Graphics
--------

* [x] OpenGL 2.1 (base + FBO) support
* [ ] Expose more than just the 2D double-triangle VAO for drawing
* [ ] `GL_ARB_direct_state_access`
* [x] Geometry shaders
* [ ] Different rendering methods:
  * [x] OpenGL 3.2 reference raytracer
  * [x] Beamtracer (requires FBO texture to use a mipmap pyramid)
  * [ ] OpenGL 2.1 raytracer/beamtracer
  * [ ] Filthy disgusting triangle mesh renderer
* [ ] Some form of raytracing antialiasing (FSAA in beamtracer perhaps?)
* [ ] PNG loading

Network
-------

* [ ] Expose Voxycodone-specific ENet sockets (ch0 generic messages, ch1 control)

VM system
---------

* [ ] Sandbox spawning:
  * [x] System sandbox
  * [ ] Client sandbox
  * [ ] Server sandbox
  * [x] Blind sandbox
  * [x] Plugin sandbox
* [x] Sandbox message passing
* [ ] Find out how to delete and/or remove sandboxes
* [ ] Delegation mode
  * [ ] Input delegation (considering returning a sandbox or list)
  * [ ] Graphics delegation (considering having a render call)

Audio
-----

* [ ] Load stuff (ogg/wav only)
* [ ] Play stuff
* [ ] Stop stuff
* [ ] Pause stuff
* [ ] Seek stuff
* [ ] Speed stuff
* [ ] Volume stuff

Filesystem
----------

* [x] Proper path security
* [x] Sandbox root directory
* [ ] Network root directory

Security
--------

* [ ] Sandbox models (# denotes available for dedicated server):
  * [x] System - can spawn Client, Server, Blind; drawable
  * [ ] Server# - can spawn Blind; can message clients + parent
  * [ ] Client - file access dictated by Server packages; drawable onto a System-provided FBO; can spawn Blind; can message server + parent
  * [x] Plugin# - can spawn Blind; can message parent
  * [x] Blind# - only has math, string, table; no message passing, just direct access from parent
* [x] Message passing system
* [ ] Wrap file access builtins to suit models:
  * [x] Local crap
  * [ ] Network client
  * [ ] Network server
* [ ] Ensure textures / FBOs don't leak between contexts

Lua code acceleration
---------------------

A lot of things could be accelerated, but for now we need to have a Lua implementation of everything first.

* [ ] C typed arrays
* [ ] Voxel scene userdata
  * [x] Voxel texture uploads
  * [ ] Voxel chunk generation

[]: # ( vim: set syntax=markdown : )

