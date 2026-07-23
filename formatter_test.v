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
