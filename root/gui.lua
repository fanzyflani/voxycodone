FONT_CW = 11*2
FONT_CH = 21*2
GUI_HPAD = 40
GUI_VPAD = 20
GUI_VSPACE = 12

do
	local data = bin_load("dat/dejavu-18-bold.tga")
	local w = 1045
	local h = 21
	local tw = 1045-1
	local th = 21
	tex_font = texture.new("2", 1, "1nb", tw, th, "nn", "1nb")
	local l = {}
	local x, y

	for y=0,th-1 do
	for x=0,tw-1 do
		local v = data:byte(0x1E+1 + y*w + x)
		l[1+y*tw+x] = (v == 2 and 0x00) or 0xFF
	end
	end

	texture.load_sub(tex_font, "2", 0, 0, 0, tw, th, "1nb", l)
end

gui = {}
gui.focused = true
gui.active = 1
gui.widgets = {}

gui.widgets[1] = {
	vm = {"self"},
	id = "main_menu",
	valid = true,
	enabled = true,

	parent = nil,

	typ = "menu",
	options = {
		"Start",
		"Host",
		"Options",
		"Help",
		"Quit",

		active = 1,
	},
}

function gui_draw_widget(sec_current, w, sx, sy, sw, sh)
	if w.typ == "menu" then
		local k, v
		local box_w = 1
		local box_h = #w.options

		for k,v in ipairs(w.options) do
			box_w = math.max(box_w, #v)
		end

		-- TODO: not hardcode this
		local menu_w = GUI_HPAD*2 + box_w*FONT_CW
		local menu_h = GUI_VPAD*2 + box_h*(FONT_CH+GUI_VSPACE) - GUI_VSPACE

		draw.viewport_set(sx + GUI_HPAD, sy + GUI_VPAD, menu_w, menu_h)
		shader.use(gui_shader_box)
		shader.uniform_f(shader.uniform_location_get(gui_shader_box, "rcolor"),
			0.3, 0.3, 0.8)
		draw.blit()

		for k,v in ipairs(w.options) do
			local l = {}
			local i
			for i=1,#v do
				l[i] = v:byte(i)
			end

			if k == w.options.active then
				draw.viewport_set(
					sx + GUI_HPAD,
					sy + GUI_VPAD*2 - GUI_VSPACE + (FONT_CH+GUI_VSPACE)*(#w.options-k),
					FONT_CW*(#v+1) + GUI_HPAD,
					FONT_CH + GUI_VSPACE*2)
				shader.use(gui_shader_box)
				shader.uniform_f(shader.uniform_location_get(gui_shader_box, "rcolor"),
					0.5, 0.5, 1.0)
				draw.blit()

				draw.viewport_set(
					sx + GUI_HPAD,
					sy + GUI_VPAD*2 - GUI_VSPACE + (FONT_CH+GUI_VSPACE)*(#w.options-k)
						+ GUI_VSPACE+3,
					FONT_CW*(#v) + GUI_HPAD,
					2)
				shader.use(gui_shader_box)
				shader.uniform_f(shader.uniform_location_get(gui_shader_box, "rcolor"),
					1.0, 1.0, 1.0)
				draw.blit()
			end

			draw.viewport_set(sx + GUI_HPAD*2, sy + GUI_VPAD*2 + (FONT_CH+GUI_VSPACE)*(#w.options-k),
				FONT_CW*#v, FONT_CH)
			shader.use(gui_shader_text)
			shader.uniform_i(shader.uniform_location_get(gui_shader_text, "str_len"), #l)
			shader.uniform_iv(shader.uniform_location_get(gui_shader_text, "str"),
				#l, 1, l)
			shader.uniform_i(shader.uniform_location_get(gui_shader_text, "tex0"), 0)
			shader.uniform_f(shader.uniform_location_get(gui_shader_text, "rcolor"),
				1.0, 1.0, 1.0)
			texture.unit_set(0, "2", tex_font)
			draw.blit()
		end
	end
end

function gui_draw(sec_current, sx, sy, sw, sh)
	sx = sx or 0
	sy = sy or 0
	sw = sw or screen_w
	sh = sh or screen_h

	local k, w
	for k, w in ipairs(gui.widgets) do
		if w.valid and w.enabled then
			gui_draw_widget(sec_current, w, sx, sy, sw, sh)
		end
	end
end

function gui_hook_key(key, state, ...)
	local w = gui.widgets[gui.active]

	if key == SDLK_ESCAPE then
		if not state then
			w.enabled = false
			gui.active = w.parent
			gui.focused = not not gui.active
		end

		return nil
	end

	if w.typ == "menu" then
		if state then
			print(string.format("%08X %08X", key, SDLK_DOWN))
			if key == SDLK_DOWN then
				w.options.active = w.options.active + 1
				if w.options.active > #w.options then
					w.options.active = 1
				end
			elseif key == SDLK_UP then
				w.options.active = w.options.active - 1
				if w.options.active < 1 then
					w.options.active = #w.options
				end
			end
		end
	end
end

gui_shader_box = shader.new({
vert=[=[
#version 130

uniform float time;

in vec2 in_vertex;

out vec2 vert_tc;
out vec2 vert_vertex;

void main()
{
	vert_tc = (in_vertex+1.0)/2.0;
	vert_vertex = in_vertex * vec2(1280.0/720.0, 1.0);
	gl_Position = vec4(in_vertex, 0.1, 1.0);
}
]=], frag = [=[
#version 130

in vec2 vert_tc;
in vec2 vert_vertex;
out vec4 out_color;

uniform vec3 rcolor;

void main()
{
	//out_color = vec4(vec3(0.33), 1.0);
	out_color = vec4(rcolor, 1.0);
}

]=]
}, {"in_vertex",}, {"out_color",})
assert(gui_shader_box)

gui_shader_text = shader.new({
vert=[=[
#version 130

uniform float time;

in vec2 in_vertex;

out vec2 vert_tc;
out vec2 vert_vertex;

void main()
{
	vert_tc = (in_vertex+1.0)/2.0;
	vert_vertex = in_vertex * vec2(1280.0/720.0, 1.0);
	gl_Position = vec4(in_vertex, 0.1, 1.0);
}
]=], frag = [=[
#version 130

in vec2 vert_tc;
in vec2 vert_vertex;
out vec4 out_color;

uniform vec3 rcolor;

uniform sampler2D tex0;
uniform int str_len;
uniform int str[256];

void main()
{
	float str_xpos = vert_tc.x*float(str_len);
	int str_idx = int(floor(str_xpos));
	float char_sx = (str_xpos - floor(str_xpos));
	char_sx *= 20.0/21.0;
	char_sx += 0.5/21.0;
	int char_idx = str[str_idx];
	float char_x = (float(char_idx - 32) + char_sx)/95.0;
	float char_y = vert_tc.y;
	char_x *= 1044.0/1045.0;
	char_x += 2.0/1044.0;

	float result = texture(tex0, vec2(char_x, char_y)).r;
	//float result = texture(tex0, vert_tc*vec2(5.0/95.0, 1.0) + vec2(0.5/1045.0, 0.5/21.0)).r;
	if(result < 0.5)
	{
		discard;
	} else {
		//out_color = vec4(vec3(result), 1.0);
		//out_color = vec4(vec3(1.0), 1.0);
		out_color = vec4(rcolor, 1.0);
	}
}

]=]
}, {"in_vertex",}, {"out_color",})
assert(gui_shader_text)

