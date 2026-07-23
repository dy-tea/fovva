module main

fn test_format_basic_if_else() {
	input := 'void f(void) {
	if(condition1) {
	do_thing1();
	}
	if(condition2) {
	do_thing2();
	}else{
	do_thing3();
	}
	}'
	expected := 'void f(void) {\n\tif (condition1) {\n\t\tdo_thing1();\n\t}\n\tif (condition2) {\n\t\tdo_thing2();\n\t} else {\n\t\tdo_thing3();\n\t}\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_indentation() {
	input := 'int main(void) {\nreturn 0;\n}\n'
	expected := 'int main(void) {\n\treturn 0;\n}\n'
	result := format(input)
	assert result == expected
}

fn test_format_nested_blocks() {
	input := 'void f(void) {
	if(a) {
	if(b) {
	x();
	}}}'
	expected := 'void f(void) {\n\tif (a) {\n\t\tif (b) {\n\t\t\tx();\n\t\t}\n\t}\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_switch_case() {
	input := 'int main(void) {
	switch(x) {
	case 1:
	do_thing();
	break;
	default:
	do_default();
	}
	}'
	expected := 'int main(void) {\n\tswitch (x) {\n\tcase 1:\n\t\tdo_thing();\n\t\tbreak;\n\tdefault:\n\t\tdo_default();\n\t}\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_spaces_indent() {
	input := 'void f(void) {
	return 0;
	}'
	cfg := Config{
		indent_style: .spaces
		indent_width: 4
	}
	result := format(input, cfg)
	expected := 'void f(void) {\n    return 0;\n}\n'
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_for_loop() {
	input := 'void f(void) {
	for(i=0;i<10;i++) {
	work();}}'
	expected := 'void f(void) {\n\tfor (i = 0; i < 10; i++) {\n\t\twork();\n\t}\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_line_breaking() {
	input := 'void f(void) {
	really_long_function(argument1, argument2, argument3, argument4, argument5);
	}'
	cfg := Config{
		max_line_len: 40
	}
	result := format(input, cfg)
	lines := result.split('\n')
	for line in lines {
		if line.len > 0 {
			assert line.len <= 45, "line too long: '${line}' (${line.len})"
		}
	}
}

fn test_format_sort_includes() {
	input := '#include "z.h"
	#include "a.h"
	#include <stdlib.h>
	#include <assert.h>
	void f(void) {}\n'
	cfg := Config{
		sort_includes: true
	}
	result := format(input, cfg)
	lines := result.split('\n')
	assert lines[0].contains('<assert.h>')
	assert lines[1].contains('<stdlib.h>')
	assert lines[2].contains('"a.h"')
	assert lines[3].contains('"z.h"')
}

fn test_format_no_sort_includes() {
	input := '#include "z.h"
	#include "a.h"

	void f(void) {}'
	cfg := Config{
		sort_includes: false
	}
	result := format(input, cfg)
	lines := result.split('\n')
	assert lines[0].contains('"z.h"')
	assert lines[1].contains('"a.h"')
}

fn test_format_empty_input() {
	result := format('')
	assert result == '\n' || result == ''
}

fn test_format_return_statement() {
	input := 'int f(void) {
	return 42;
	}'
	expected := 'int f(void) {\n\treturn 42;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_multiple_functions() {
	input := 'void a(void) {
	x();
	}
	void b(void) {
	y();
	}'
	expected := 'void a(void) {\n\tx();\n}\n\nvoid b(void) {\n\ty();\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_do_while() {
	input := 'void f(void) {
	do {
	x();
	} while(cond);
	}'
	expected := 'void f(void) {\n\tdo {\n\t\tx();\n\t} while (cond);\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_else_if() {
	input := 'void f(void) {
	if(a) {
	x();
	}
	else if (b){
	y();
	}else {
	z();
	}}'
	expected := 'void f(void) {\n\tif (a) {\n\t\tx();\n\t} else if (b) {\n\t\ty();\n\t} else {\n\t\tz();\n\t}\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_struct_init() {
	input := 'struct S {
	int a;
	int b;
	};

	int main() {
	S s={};
	S ss = {1 , 2};
	S sss = {.a = 1, .b = 2};

	return 0;
	}'
	expected := 'struct S {\n\tint a;\n\tint b;\n};\n\nint main() {\n\tS s = {};\n\tS ss = {\n\t\t1,\n\t\t2\n\t};\n\tS sss = {\n\t\t.a = 1,\n\t\t.b = 2\n\t};\n\n\treturn 0;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_struct_cast() {
	input := 'struct S {
	int a; int b;
	};

	S src = (struct S){
	.a = 0xa,
	.b = 0xb,
	};'
	expected := 'struct S {\n\tint a;\n\tint b;\n};\n\nS src = (struct S){\n\t.a = 0xa,\n\t.b = 0xb,\n};\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_pointer_basic() {
	input := 'void f(void) {
	int *p = NULL;
	int **pp;
	*p = 42;
	int x = a * b;
	int y = a & b;
	int *q = &x;
	f(&x, &y);
	return *p;
	}'
	expected := 'void f(void) {\n\tint *p = NULL;\n\tint **pp;\n\t*p = 42;\n\tint x = a * b;\n\tint y = a & b;\n\tint *q = &x;\n\tf(&x, &y);\n\treturn *p;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_pointer_advanced() {
	input := 'void f(void) {
	struct foo *p = NULL;
	T *q = NULL;
	sizeof(*p);
	void *ptr;
	size_t s = sizeof(*p);
	}'
	expected := 'void f(void) {\n\tstruct foo *p = NULL;\n\tT *q = NULL;\n\tsizeof(*p);\n\tvoid *ptr;\n\tsize_t s = sizeof(*p);\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_pointer_params() {
	input := 'void update(struct wlr_surface *sans) {
	bool *flag;
	int _unused_x, _unused_y;
	if (sans != surface && wlr_scene_node_coords(&tree->node, &_unused_x)) {
	inhibited = true;
	}
	}'
	expected := 'void update(struct wlr_surface *sans) {\n\tbool *flag;\n\tint _unused_x, _unused_y;\n\tif (sans != surface && wlr_scene_node_coords(&tree->node, &_unused_x)) {\n\t\tinhibited = true;\n\t}\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_pointer_typedef() {
	input := 'void handle_destroy(struct wl_listener *listener, void *data) {
	(void)data;
	MyType *idle = container_of(listener, idle, member);
	free(idle);
	}'
	expected := 'void handle_destroy(struct wl_listener *listener, void *data) {\n\t(void)data;\n\tMyType *idle = container_of(listener, idle, member);\n\tfree(idle);\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_pointer_return_addr() {
	input := 'int *f(int *p) {
	return p;
	}
	int *g(int *p) {
	int *q = &x;
	return &x;
	}'
	expected := 'int *f(int *p) {\n\treturn p;\n}\n\nint *g(int *p) {\n\tint *q = &x;\n\treturn &x;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_if_without_braces() {
	input := 'void f(void) {
	if (cond) stmt;
	}'
	expected := 'void f(void) {\n\tif (cond)\n\t\tstmt;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_if_else_without_braces() {
	input := 'void f(void) {
	if (cond) stmt; else stmt2;
	}'
	expected := 'void f(void) {\n\tif (cond)\n\t\tstmt;\n\telse\n\t\tstmt2;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_else_if_naked() {
	input := 'void f(void) {
	if (a) stmt; else if (b) stmt2; else stmt3;
	}'
	expected := 'void f(void) {\n\tif (a)\n\t\tstmt;\n\telse if (b)\n\t\tstmt2;\n\telse\n\t\tstmt3;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_while_without_braces() {
	input := 'void f(void) {
	while (cond) stmt;
	}'
	expected := 'void f(void) {\n\twhile (cond)\n\t\tstmt;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_for_without_braces() {
	input := 'void f(void) {
	for (;;) stmt;
	}'
	expected := 'void f(void) {\n\tfor (; ; )\n\t\tstmt;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_nested_if_without_braces() {
	input := 'void f(void) {
	if (a) if (b) stmt;
	}'
	expected := 'void f(void) {\n\tif (a)\n\t\tif (b)\n\t\t\tstmt;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_unary_operators() {
	input := 'int f(void) {
	return -1;
	int x = -y;
	int z = +1;
	int w = a - b;
	int v = a + -b;
	}'
	expected := 'int f(void) {\n\treturn -1;\n\tint x = -y;\n\tint z = +1;\n\tint w = a - b;\n\tint v = a + -b;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_macro_body_indent() {
	input := 'void f(void) {
	wl_list_for_each(entry, &list, link)
	if (cond)
	    stmt;
	}'
	expected := 'void f(void) {\n\twl_list_for_each(entry, &list, link)\n\t\tif (cond)\n\t\t\tstmt;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_static_ptr_decl() {
	input := 'static mytype *q = NULL;
	void f(mytype *p) {}
	mytype *r;
	void g(struct S *s) {}'
	expected := 'static mytype *q = NULL;\nvoid f(mytype *p) {} mytype * r;\nvoid g(struct S *s) {}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_ternary_basic() {
	input := 'void f(void) {
	int x = a ? b : c;
	}'
	expected := 'void f(void) {\n\tint x = a ? b : c;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_ternary_complex() {
	input := 'int g(void) {
	int x = something() ? something() : 0;
	int y = a ? &b : NULL;
	int z = a ? *b : NULL;
	int w = a ? b ? c : d : e;
	}'
	expected := 'int g(void) {\n\tint x = something() ? something() : 0;\n\tint y = a ? &b : NULL;\n\tint z = a ? *b : NULL;\n\tint w = a ? b ? c : d : e;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_comma_lparen() {
	input := 'void f(void) {
	printf("%d %s", x, (void *)ptr);
	func(a, (int)b);
	}'
	expected := 'void f(void) {\n\tprintf("%d %s", x, (void *)ptr);\n\tfunc(a, (int)b);\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_inline_comment_after_semicolon() {
	input := 'void do_something(int *val) {
	*val = 12;
	}

	int main() {
	int a = 100;
	do_something(&a); // inline comment explaining this
	}'
	expected := 'void do_something(int *val) {\n\t*val = 12;\n}\n\nint main() {\n\tint a = 100;\n\tdo_something(&a); // inline comment explaining this\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_inline_comment_after_return() {
	input := 'void f(void) {
	x = 1; // trailing comment
	return; // return comment
	}'
	expected := 'void f(void) {\n\tx = 1; // trailing comment\n\treturn; // return comment\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_standalone_line_comment() {
	input := 'void f(void) {
	// standalone comment at block start
	int x = 1;
	}'
	expected := 'void f(void) {\n\t// standalone comment at block start\n\tint x = 1;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_cast_arithmetic() {
	input := 'void f(void) {
	curve->baked[i].x = (float)(b0 * p0x + b1 * p1x);
	float t = (float)((x - x0) / (x1 - x0));
	}'
	expected := 'void f(void) {\n\tcurve->baked[i].x = (float)(b0 * p0x + b1 * p1x);\n\tfloat t = (float)((x - x0) / (x1 - x0));\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_cast_mult_after_rparen() {
	input := 'void f(void) {
	float x = (float)(a) * 16;
	}'
	expected := 'void f(void) {\n\tfloat x = (float)(a) * 16;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_unary_at_line_start() {
	input := 'void f(void) {
	if (cond)
	    *val = 12;
	}
	void g(void) {
	*val = 42;
	}'
	expected := 'void f(void) {\n\tif (cond)\n\t\t*val = 12;\n}\n\nvoid g(void) {\n\t*val = 42;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_control_flow_mult() {
	input := 'void f(void) {
	while (a * b) { body(); }
	if (a * b) { body(); }
	for (a * b; ;) { body(); }
	int x = a * b;
	}'
	expected := 'void f(void) {\n\twhile (a * b) {\n\t\tbody();\n\t}\n\tif (a * b) {\n\t\tbody();\n\t}\n\tfor (a * b; ; ) {\n\t\tbody();\n\t}\n\tint x = a * b;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_typedef_struct_brace() {
	input := 'typedef struct {
	char strings[64];
	size_t count;
} foo;'
	expected := 'typedef struct {\n\tchar strings[64];\n\tsize_t count;\n} foo;\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_typedef_union_brace() {
	input := 'typedef union {
	int i;
	float f;
} bar;'
	expected := 'typedef union {\n\tint i;\n\tfloat f;\n} bar;\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_typedef_enum_brace() {
	input := 'typedef enum { A, B } myenum;'
	expected := 'typedef enum {\n\tA, B\n} myenum;\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_inline_init_zero() {
	input := 'void f(void) {
	int arr[] = {0};
	}'
	expected := 'void f(void) {\n\tint arr[] = {0};\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_inline_init_null() {
	input := 'void f(void) {
	char *s = {NULL};
	}'
	expected := 'void f(void) {\n\tchar *s = {NULL};\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_multi_element_init_expands() {
	input := 'void f(void) {
	int arr[] = {0, 1};
	}'
	expected := 'void f(void) {\n\tint arr[] = {\n\t\t0,\n\t\t1\n\t};\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_comment_between_structs() {
	input := 'struct Struct {
	int a;
	int b;
	}

	// comment about AnotherStruct
	struct AnotherStruct {
	int b;
	}'
	expected := 'struct Struct {\n\tint a;\n\tint b;\n}\n\n// comment about AnotherStruct\nstruct AnotherStruct {\n\tint b;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_compound_literal_expansion() {
	input := 'void f(void) {
	func(arg, &(struct S){.x = 1, .y = 2});
	}'
	expected := 'void f(void) {\n\tfunc(arg, &(struct S){\n\t\t.x = 1,\n\t\t.y = 2\n\t});\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_macro_loop_body() {
	input := 'void f(void) {
	MACRO(item, &list, link) stmt(arg);
	}'
	expected := 'void f(void) {\n\tMACRO(item, &list, link)\n\t\tstmt(arg);\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_nested_for_without_braces() {
	input := 'static void tabs_rebuild_all(void) {
	for (output_t *m = mon_head; m; m = m->next)
		for (desktop_t *d = m->desk; d; d = d->next)
			if (d->root)
				tabs_rebuild(d->root);
}
'
	expected := 'static void tabs_rebuild_all(void) {\n\tfor (output_t *m = mon_head; m; m = m->next)\n\t\tfor (desktop_t *d = m->desk; d; d = d->next)\n\t\t\tif (d->root)\n\t\t\t\ttabs_rebuild(d->root);\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_switch_case_indent() {
	input := 'switch (decoration_mode) {
case DECORATION_NONE:
    mode_str = "none\\n";
    break;
case DECORATION_TABS:
    mode_str = "tabs\\n";
    break;
case DECORATION_ALWAYS:
    mode_str = "always\\n";
    break;
case DECORATION_CSD:
    mode_str = "csd\\n";
    break;
}
'
	expected := 'switch (decoration_mode) {\ncase DECORATION_NONE:\n\tmode_str = "none\\n";\n\tbreak;\ncase DECORATION_TABS:\n\tmode_str = "tabs\\n";\n\tbreak;\ncase DECORATION_ALWAYS:\n\tmode_str = "always\\n";\n\tbreak;\ncase DECORATION_CSD:\n\tmode_str = "csd\\n";\n\tbreak;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_struct_array_init() {
	input := 'static const tab_cfg_t tab_colors[] = {
    {"bar_bg", color_bar_bg},
    {"bg", color_tab_bg},
    {"bg_active", color_tab_bg_active},
    {"text", color_tab_text},
    {"text_active", color_tab_text_active},
    {"sep", color_tab_sep},
};
'
	expected := 'static const tab_cfg_t tab_colors[] = {\n\t{"bar_bg", color_bar_bg},\n\t{"bg", color_tab_bg},\n\t{"bg_active", color_tab_bg_active},\n\t{"text", color_tab_text},\n\t{"text_active", color_tab_text_active},\n\t{"sep", color_tab_sep},\n};\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_string_not_broken_by_line_breaker() {
	input := 'void f(void) {
	offset += snprintf(buf, sizeof(buf),
	"    {\\"name\\": \\"%s\\", \\"id\\": %u, \\"rect\\": {\\"x\\": %d, \\"y\\": %d, \\"width\\": %d, \\"height\\": %d}}",
	m->name, m->id);
}
'
	cfg := Config{
		max_line_len: 60
	}
	result := format(input, cfg)
	lines := result.split('\n')
	for line in lines {
		mut in_str := false
		mut i := 0
		for i < line.len {
			if line[i] == `"` && !(i > 0 && line[i - 1] == `\\`) {
				in_str = !in_str
			}
			i++
		}
		if in_str {
			assert false, 'line has unbalanced quotes: \'${line}\''
		}
	}
}

fn test_comment_long_lines_preserve_syntax() {
	input := '// Error a a fugit voluptas ab repellendus corporis. Dolor debitis est quia quia sapiente.
// Officiis et numquam quis inventore assumenda blanditiis eligendi alias. Tenetur unde inventore error facilis maiores non eum sapiente.
'
	cfg := Config{
		max_line_len: 60
	}
	result := format(input, cfg)
	lines := result.split('\n')
	for line in lines {
		if line.len > 0 {
			trimmed := line.trim_space()
			if trimmed.len > 0 && !trimmed.starts_with('//') {
				assert false, 'comment continuation missing //: \'${line}\''
			}
		}
	}
}

fn test_binary_and_spacing() {
	input := 'if (!(mask&WL_EVENT_READABLE))return 0;'
	expected := 'if (!(mask & WL_EVENT_READABLE))\n\treturn 0;\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_post_decrement_assignment() {
	input := "*end--='\\0';"
	expected := "*end-- = '\\0';\n"
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_cast_sizeof_no_space() {
	input := 'offset < (int)sizeof(pending_command) - 1;'
	expected := 'offset < (int)sizeof(pending_command) - 1;\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_for_null_body_indent() {
	input := 'void f(void) {for (;;);}'
	expected := 'void f(void) {\n\tfor (; ; )\n\t\t;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_cast_rparen_unary_op() {
	input := 'destroy_fbo((GLuint *)&state->ping.native_handle[0], (GLuint *)&state->ping.native_handle[1]);'
	expected := 'destroy_fbo((GLuint *)&state->ping.native_handle[0], (GLuint *)&state->ping.native_handle[1]);\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_nested_init_brace_indent() {
	input := 'Foo arr[2] = {{.sType = A,.stage = B,},{.sType = C,.stage = D,},};'
	expected := 'Foo arr[2] = {\n\t{\n\t\t.sType = A,\n\t\t.stage = B,\n\t},\n\t{\n\t\t.sType = C,\n\t\t.stage = D,\n\t},\n};\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_statement_after_block() {
	input := 'void f(void) {
	if (cond) { body(); }
	if (val < min)
	val = min;
	if (val > max)
	val = max;
}
*var = val;
'
	expected := 'void f(void) {\n\tif (cond) {\n\t\tbody();\n\t}\n\tif (val < min)\n\t\tval = min;\n\tif (val > max)\n\t\tval = max;\n}\n\n*var = val;\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_compound_literal_operator() {
	input := 'void f(void) {
	int *p = (struct S){ .x = 1 } + 5;
}
'
	expected := 'void f(void) {\n\tint *p = (struct S){\n\t\t.x = 1\n\t} + 5;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_comment_after_semicolon_separate_line() {
	input := 'void f(void) {
	int x = 1;

	// comment on its own line
	int y = 2;
}
'
	expected := 'void f(void) {\n\tint x = 1;\n\n\t// comment on its own line\n\tint y = 2;\n}\n'
	result := format(input)
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}
