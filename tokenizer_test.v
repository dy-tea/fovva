module main

fn test_tokenize_basic_keywords() {
	tokens := tokenize('if else for while do return int void char')
	assert tokens.len > 0
	assert tokens[0].typ == .kw_if
	assert tokens[0].value == 'if'
	assert tokens[1].typ == .kw_else
	assert tokens[2].typ == .kw_for
	assert tokens[3].typ == .kw_while
	assert tokens[4].typ == .kw_do
	assert tokens[5].typ == .kw_return
	assert tokens[6].typ == .kw_int
	assert tokens[7].typ == .kw_void
	assert tokens[8].typ == .kw_char
}

fn test_tokenize_braces() {
	tokens := tokenize('{}()[];,')
	assert tokens[0].typ == .lbrace
	assert tokens[1].typ == .rbrace
	assert tokens[2].typ == .lparen
	assert tokens[3].typ == .rparen
	assert tokens[4].typ == .lbracket
	assert tokens[5].typ == .rbracket
	assert tokens[6].typ == .semicolon
	assert tokens[7].typ == .comma
}

fn test_tokenize_string_literal() {
	tokens := tokenize('"hello world"')
	assert tokens[0].typ == .string_lit
	assert tokens[0].value == '"hello world"'
}

fn test_tokenize_char_literal() {
	tokens := tokenize("'x'")
	assert tokens[0].typ == .char_lit
	assert tokens[0].value == "'x'"
}

fn test_tokenize_numbers() {
	tokens := tokenize('42 0xFF 3.14')
	assert tokens[0].typ == .number
	assert tokens[0].value == '42'
	assert tokens[1].typ == .number
	assert tokens[1].value == '0xFF'
	assert tokens[2].typ == .number
	assert tokens[2].value == '3.14'
}

fn test_tokenize_hex_suffix() {
	tokens := tokenize('0xFFFFFFFFu 0xFFUL 0x1UL')
	assert tokens[0].typ == .number
	assert tokens[0].value == '0xFFFFFFFFu'
	assert tokens[1].typ == .number
	assert tokens[1].value == '0xFFUL'
	assert tokens[2].typ == .number
	assert tokens[2].value == '0x1UL'
}

fn test_tokenize_operators() {
	tokens := tokenize('== != <= >= && || ++ -- ->')
	mut op_count := 0
	mut arrow_count := 0
	for t in tokens {
		if t.typ == .newline || t.typ == .eof {
			continue
		}
		if t.typ == .operator { op_count++ }
		if t.typ == .arrow { arrow_count++ }
	}
	assert op_count == 8
	assert arrow_count == 1
}

fn test_tokenize_comments() {
	tokens := tokenize('// line comment\n/* block comment */')
	assert tokens[0].typ == .line_comment
	assert tokens[0].value == '// line comment'
	assert tokens[1].typ == .newline
	assert tokens[2].typ == .block_comment
	assert tokens[2].value == '/* block comment */'
}

fn test_tokenize_include() {
	tokens := tokenize('#include <stdio.h>\n#include "local.h"')
	assert tokens.count(|t| t.typ == .pp_include) == 2
}

fn test_tokenize_empty_input() {
	tokens := tokenize('')
	assert tokens.len == 1
	assert tokens[0].typ == .eof
}

fn test_tokenize_identifiers() {
	tokens := tokenize('foo bar _baz')
	assert tokens[0].typ == .identifier
	assert tokens[0].value == 'foo'
	assert tokens[1].typ == .identifier
	assert tokens[1].value == 'bar'
	assert tokens[2].typ == .identifier
	assert tokens[2].value == '_baz'
}

fn test_tokenize_struct_keyword() {
	tokens := tokenize('struct mystruct { int x; };')
	assert tokens[0].typ == .kw_struct
	assert tokens[1].typ == .identifier
	assert tokens[1].value == 'mystruct'
	assert tokens[2].typ == .lbrace
}
