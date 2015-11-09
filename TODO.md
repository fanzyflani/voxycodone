Cleanup
-------

This really should happen before the other things.

[ ] Port src/voxel.c to Lua
[ ] Split src/lbind.c into different files
[ ] Port the main loop to Lua
[ ] Make API docs

API
---

[ ] Expose more stuff in libs:
  [ ] 1D textures
  [ ] Cubemaps
  [ ] Fill in all dims for these (TODOs in brackets):
    [ ] texture.load_sub (1D, 3D)
    [ ] texture.new (1D)
  [ ] `matrix.*`
  [ ] `shader.uniform_*`

Game engine
-----------

[ ] Physics

Graphics
--------

[ ] Expose more than just the 2D double-triangle VAO for drawing
[ ] `GL_ARB_direct_state_access`
[ ] Geometry shaders
[ ] Different rendering methods:
  [x] OpenGL 3.2 reference raytracer
  [ ] Beamtracer (requires FBO texture to use a mipmap pyramid)
  [ ] OpenGL 2.1 raytracer/beamtracer
  [ ] Filthy disgusting triangle mesh renderer
[ ] Some form of raytracing antialiasing (FSAA in beamtracer perhaps?)

Network
-------

[ ] Expose Voxycodone-specific ENet sockets (ch0 generic messages, ch1 control)

VM system
---------

[ ] Sandbox spawning:
  [ ] Network-client sandbox
  [ ] Network-server sandbox
  [ ] Personal config sandbox
[ ] Sandbox message passing

Lua code acceleration
---------------------

A lot of things could be accelerated, but for now we need to have a Lua implementation of everything first.

[ ] C typed arrays
[ ] Voxel scene userdata
  [ ] Voxel texture uploads
  [ ] Voxel chunk generation

