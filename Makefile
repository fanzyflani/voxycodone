# I personally don't care if you steal this makefile. --GM

CFLAGS = -g -O2 `sdl2-config --cflags` `./findlua.sh --cflags` `pkg-config epoxy --cflags` -I.
LDFLAGS = -g
LIBS = `sdl2-config --libs` -lSDL2_mixer `./findlua.sh --libs` `pkg-config epoxy --libs` -lGL -lm
BINNAME = voxycodone
OBJDIR = obj

include Makefile.common

