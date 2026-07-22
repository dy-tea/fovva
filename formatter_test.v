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
	result := format(input, Config{})
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_indentation() {
	input := 'int main(void) {\nreturn 0;\n}\n'
	expected := 'int main(void) {\n\treturn 0;\n}\n'
	result := format(input, Config{})
	assert result == expected
}

fn test_format_nested_blocks() {
	input := 'void f(void) {
	if(a) {
	if(b) {
	x();
	}}}'
	expected := 'void f(void) {\n\tif (a) {\n\t\tif (b) {\n\t\t\tx();\n\t\t}\n\t}\n}\n'
	result := format(input, Config{})
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
	result := format(input, Config{})
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
	result := format(input, Config{})
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
	result := format('', Config{})
	assert result == '\n' || result == ''
}

fn test_format_return_statement() {
	input := 'int f(void) {
	return 42;
	}'
	expected := 'int f(void) {\n\treturn 42;\n}\n'
	result := format(input, Config{})
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
	result := format(input, Config{})
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_format_do_while() {
	input := 'void f(void) {
	do {
	x();
	} while(cond);
	}'
	expected := 'void f(void) {\n\tdo {\n\t\tx();\n\t} while (cond);\n}\n'
	result := format(input, Config{})
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
	result := format(input, Config{})
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
	result := format(input, Config{})
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
	result := format(input, Config{})
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
	result := format(input, Config{})
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
	result := format(input, Config{})
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
	result := format(input, Config{})
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}

fn test_pointer_typedef() {
	input := 'void handle_destroy(struct wl_listener *listener, void *data) {
	(void)data;
	MyType *idle = container_of(listener, idle, member);
	free(idle);
	}'
	expected := 'void handle_destroy(struct wl_listener *listener, void *data) {\n\t(void)data;\n\tMyType *idle = container_of(listener, idle, member);\n\tfree(idle);\n}\n'
	result := format(input, Config{})
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
	result := format(input, Config{})
	assert result == expected, 'got:\n${result}\nexpected:\n${expected}'
}
