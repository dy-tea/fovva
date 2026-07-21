module main

pub enum TokenType {
	eof
	newline
	identifier
	string_lit
	char_lit
	number
	lbrace
	rbrace
	lparen
	rparen
	lbracket
	rbracket
	semicolon
	comma
	colon
	question
	dot
	arrow
	kw_if
	kw_else
	kw_for
	kw_while
	kw_do
	kw_switch
	kw_case
	kw_return
	kw_break
	kw_continue
	kw_struct
	kw_union
	kw_enum
	kw_typedef
	kw_static
	kw_extern
	kw_const
	kw_void
	kw_char
	kw_int
	kw_short
	kw_long
	kw_float
	kw_double
	kw_signed
	kw_unsigned
	kw_sizeof
	kw_auto
	kw_register
	kw_volatile
	kw_goto
	kw_default
	operator
	pp_include
	pp_define
	pp_other
	line_comment
	block_comment
}

pub struct Token {
	typ    TokenType
	value  string
	line   int
	column int
}

fn kw_type(word string) !TokenType {
	match word {
		'if' { return .kw_if }
		'else' { return .kw_else }
		'for' { return .kw_for }
		'while' { return .kw_while }
		'do' { return .kw_do }
		'switch' { return .kw_switch }
		'case' { return .kw_case }
		'return' { return .kw_return }
		'break' { return .kw_break }
		'continue' { return .kw_continue }
		'struct' { return .kw_struct }
		'union' { return .kw_union }
		'enum' { return .kw_enum }
		'typedef' { return .kw_typedef }
		'static' { return .kw_static }
		'extern' { return .kw_extern }
		'const' { return .kw_const }
		'void' { return .kw_void }
		'char' { return .kw_char }
		'int' { return .kw_int }
		'short' { return .kw_short }
		'long' { return .kw_long }
		'float' { return .kw_float }
		'double' { return .kw_double }
		'signed' { return .kw_signed }
		'unsigned' { return .kw_unsigned }
		'sizeof' { return .kw_sizeof }
		'auto' { return .kw_auto }
		'register' { return .kw_register }
		'volatile' { return .kw_volatile }
		'goto' { return .kw_goto }
		'default' { return .kw_default }
		else { return error('') }
	}
}

fn is_ident_start(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`
}

fn is_ident_continue(c u8) bool {
	return is_ident_start(c) || (c >= `0` && c <= `9`)
}

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn is_hex_digit(c u8) bool {
	return is_digit(c) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}

fn is_space(c u8) bool {
	return c == ` ` || c == `\t`
}

fn is_binary_op(val string) bool {
	return match val {
		'==', '!=', '<', '>', '<=', '>=', '&&', '||', '+', '-', '*', '/', '%', '=', '+=', '-=',
		'*=', '/=', '%=', '&=', '|=', '^=', '&', '|', '^', '<<', '>>', '<<=', '>>=' {
			true
		}
		else {
			false
		}
	}
}

pub fn tokenize(source string) []Token {
	mut tokens := []Token{}
	mut pos := 0
	mut line := 1
	mut col := 1
	n := source.len

	for pos < n {
		c := source[pos]

		if c == `\n` {
			tokens << Token{.newline, '\n', line, col}
			pos++
			line++
			col = 1
			continue
		}

		if c == `\r` {
			pos++
			col++
			continue
		}

		if is_space(c) {
			pos++
			col++
			continue
		}

		if c == `/` && pos + 1 < n {
			if source[pos + 1] == `/` {
				start := pos
				pos += 2
				col += 2
				for pos < n && source[pos] != `\n` {
					pos++
					col++
				}
				tokens << Token{.line_comment, source[start..pos], line, col - (pos - start)}
				continue
			}
			if source[pos + 1] == `*` {
				start := pos
				pos += 2
				col += 2
				for pos < n {
					if source[pos] == `\n` {
						line++
						col = 1
						pos++
						continue
					}
					if source[pos] == `*` && pos + 1 < n && source[pos + 1] == `/` {
						pos += 2
						col += 2
						break
					}
					pos++
					col++
				}
				tokens << Token{.block_comment, source[start..pos], line, col - (pos - start)}
				continue
			}
		}

		if c == `"` {
			start := pos
			pos++
			col++
			for pos < n {
				if source[pos] == `\\` {
					pos += 2
					col += 2
					continue
				}
				if source[pos] == `"` {
					pos++
					col++
					break
				}
				if source[pos] == `\n` {
					line++
					col = 1
				}
				pos++
				col++
			}
			tokens << Token{.string_lit, source[start..pos], line, col - (pos - start)}
			continue
		}

		if c == `'` {
			start := pos
			pos++
			col++
			for pos < n {
				if source[pos] == `\\` {
					pos += 2
					col += 2
					continue
				}
				if source[pos] == `'` {
					pos++
					col++
					break
				}
				if source[pos] == `\n` {
					line++
					col = 1
				}
				pos++
				col++
			}
			tokens << Token{.char_lit, source[start..pos], line, col - (pos - start)}
			continue
		}

		if is_digit(c) || (c == `.` && pos + 1 < n && is_digit(source[pos + 1])) {
			start := pos
			pos++
			col++
			if c == `0` && pos < n && (source[pos] == `x` || source[pos] == `X`) {
				pos++
				col++
				for pos < n && is_hex_digit(source[pos]) {
					pos++
					col++
				}
			} else {
				for pos < n && is_digit(source[pos]) {
					pos++
					col++
				}
				if pos < n && source[pos] == `.` {
					pos++
					col++
					for pos < n && is_digit(source[pos]) {
						pos++
						col++
					}
				}
				if pos < n && (source[pos] == `e` || source[pos] == `E`) {
					pos++
					col++
					if pos < n && (source[pos] == `+` || source[pos] == `-`) {
						pos++
						col++
					}
					for pos < n && is_digit(source[pos]) {
						pos++
						col++
					}
				}
				for pos < n && (source[pos] == `u` || source[pos] == `U`
					|| source[pos] == `l` || source[pos] == `L` || source[pos] == `f`
					|| source[pos] == `F`) {
					pos++
					col++
				}
			}
			tokens << Token{.number, source[start..pos], line, col - (pos - start)}
			continue
		}

		if is_ident_start(c) {
			start := pos
			pos++
			col++
			for pos < n && is_ident_continue(source[pos]) {
				pos++
				col++
			}
			word := source[start..pos]
			tok_type := kw_type(word) or { TokenType.identifier }
			tokens << Token{tok_type, word, line, col - (pos - start)}
			continue
		}

		if c == `#` {
			start := pos
			pos++
			col++
			for pos < n && is_space(source[pos]) {
				pos++
				col++
			}
			if pos < n && is_ident_start(source[pos]) {
				dir_start := pos
				for pos < n && is_ident_continue(source[pos]) {
					pos++
					col++
				}
				dir := source[dir_start..pos]
				for pos < n && source[pos] != `\n` {
					if source[pos] == `\\` && pos + 1 < n && source[pos + 1] == `\n` {
						pos += 2
						line++
						col = 1
					} else {
						pos++
						col++
					}
				}
				line_text := source[start..pos]
				match dir {
					'include' { tokens << Token{.pp_include, line_text, line, col - (pos - start)} }
					'define' { tokens << Token{.pp_define, line_text, line, col - (pos - start)} }
					else { tokens << Token{.pp_other, line_text, line, col - (pos - start)} }
				}
			} else {
				tokens << Token{.operator, '#', line, col - 1}
				pos++
			}
			continue
		}

		if pos + 1 < n {
			two := source[pos..pos + 2]
			match two {
				'->' {
					tokens << Token{.arrow, '->', line, col}
					pos += 2
					col += 2
					continue
				}
				'==', '!=', '<=', '>=', '&&', '||', '++', '--', '+=', '-=', '*=', '/=', '%=', '&=',
				'|=', '^=', '<<', '>>' {
					if (two == '<<' || two == '>>') && pos + 2 < n && source[pos + 2] == `=` {
						tokens << Token{.operator, source[pos..pos + 3], line, col}
						pos += 3
						col += 3
					} else {
						tokens << Token{.operator, two, line, col}
						pos += 2
						col += 2
					}
					continue
				}
				else {}
			}
		}

		match c {
			`{` { tokens << Token{.lbrace, '{', line, col} }
			`}` { tokens << Token{.rbrace, '}', line, col} }
			`(` { tokens << Token{.lparen, '(', line, col} }
			`)` { tokens << Token{.rparen, ')', line, col} }
			`[` { tokens << Token{.lbracket, '[', line, col} }
			`]` { tokens << Token{.rbracket, ']', line, col} }
			`;` { tokens << Token{.semicolon, ';', line, col} }
			`,` { tokens << Token{.comma, ',', line, col} }
			`.` { tokens << Token{.dot, '.', line, col} }
			`:` { tokens << Token{.colon, ':', line, col} }
			`?` { tokens << Token{.question, '?', line, col} }
			else { tokens << Token{.operator, c.ascii_str(), line, col} }
		}

		pos++
		col++
	}

	tokens << Token{.eof, '', line, col}
	return tokens
}
