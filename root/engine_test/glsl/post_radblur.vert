// vim: syntax=c
#version 150

out vec2 tc;
in vec2 in_vertex;

void main()
{
	tc = (in_vertex+1.0)/2.0;
	gl_Position = vec4(in_vertex, 0.1, 1.0);
}

