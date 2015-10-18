# I personally don't care if you steal this makefile. --GM

CFLAGS = -g -O2 `sdl2-config --cflags` -I/usr/local/include/ -I.
LDFLAGS = -g
LIBS = `sdl2-config --libs` -lepoxy -lGL -lm
BINNAME = tfiy
OBJDIR = obj
SRCDIR = src
INCDIR = src
INCLUDES = $(INCDIR)/common.h
OBJS = \
	$(OBJDIR)/glslpp.o \
	$(OBJDIR)/init.o \
	$(OBJDIR)/kd.o \
	$(OBJDIR)/scene.o \
	$(OBJDIR)/sph.o \
	\
	$(OBJDIR)/main.o

all: $(BINNAME) $(TOOLS)

clean:
	rm -f $(OBJS)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINNAME): $(OBJDIR) $(OBJS)
	$(CC) -o $(BINNAME) $(LDFLAGS) $(OBJS) $(LIBS)

$(OBJDIR)/%.o: $(SRCDIR)/%.c $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<

.PHONY: all clean


