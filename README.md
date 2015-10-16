WIP raytracer for demosplash 2015

by GreaseMonkey

dependencies: SDL2, libepoxy

uses datenwolf's linmath.h "licensed" under WTFPLv2 (Public Domain)

my compile + run flags:

    cc -O2 -o ds15-gm main.c `sdl2-config --cflags --libs` -I/usr/local/include -lepoxy -lGL -lm && ./ds15-gm

run from this directory or else it will choke, this is NOT the time to do stupid getcwd hacks this early in development

licence TBD, probably will be GPL

