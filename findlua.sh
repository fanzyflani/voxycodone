#!/bin/sh

# Because EVERY DISTRO JUST HAS TO INSIST ON DOING IT DIFFERENTLY
# IT'S LIKE THESE MORONS DON'T KNOW WHAT STANDARDS ARE

# oh yeah, i release this into the public domain.

if pkg-config lua-5.3 ; then
	# FreeBSD
	pkg-config lua-5.3 $@
elif pkg-config lua5.3 ; then
	# Debian
	pkg-config lua5.3 $@
elif pkg-config lua --atleast-version 5.3 --max-version 5.3.9999 ; then
	# Slackware?
	pkg-config lua $@
else
	echo Lua 5.3 not found - tweak findlua.sh to suit your liking. 1>&2
fi

