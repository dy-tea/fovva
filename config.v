module main

enum IndentStyle {
	tabs
	spaces
}

struct Config {
	max_line_len  int         = 100
	sort_includes bool        = true
	indent_style  IndentStyle = .tabs
	indent_width  int         = 8
}
