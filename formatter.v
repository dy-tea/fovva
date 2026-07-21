module main

import strings

struct FormatContext {
	config Config
	tokens []Token
mut:
	sb              strings.Builder
	indent_lvl      int
	brace_depth     int
	line_start      bool
	prev_tok        Token
	paren_depth     int
	in_for          bool
	in_case         bool
	prev_newline    bool
	skip_rbrace     bool
	paren_cast      []bool
	last_cast_paren bool
}

pub fn format(source string, cfg Config) string {
	src := if cfg.sort_includes { sort_includes(source) } else { source }
	tokens := tokenize(src)
	mut ctx := FormatContext{
		config:       cfg
		tokens:       tokens
		sb:           strings.new_builder(4096)
		indent_lvl:   0
		brace_depth:  0
		line_start:   true
		in_case:      false
		prev_newline: false
	}
	ctx.run()
	mut result := ctx.sb.str()
	if cfg.max_line_len > 0 {
		result = break_long_lines(result, cfg)
	}
	return result
}

fn break_long_lines(text string, cfg Config) string {
	mut lines := text.split('\n')
	mut result := []string{}
	for line in lines {
		if line.len <= cfg.max_line_len {
			result << line
			continue
		}
		prefix := leading_whitespace_len(line)
		continuation_indent := calc_cont_indent(line, prefix, cfg)
		cont_str := match cfg.indent_style {
			.tabs {
				strings.repeat_string('\t', continuation_indent)
			}
			.spaces {
				strings.repeat_string(' ', continuation_indent * cfg.indent_width)
			}
		}

		mut remaining := line
		for remaining.len > cfg.max_line_len {
			best_pos := find_break_pos(remaining, prefix, cfg.max_line_len)
			if best_pos <= prefix || best_pos >= remaining.len - 1 {
				break
			}
			result << remaining[..best_pos]
			remaining = cont_str + remaining[best_pos..].trim_left(' ')
		}
		result << remaining
	}
	return result.join('\n')
}

fn find_break_pos(line string, prefix_len int, max_len int) int {
	end := if max_len < line.len { max_len } else { line.len - 1 }
	mut best_op := -1
	mut best_space := -1
	for pos := end; pos > prefix_len; pos-- {
		if pos + 1 < line.len {
			if line[pos] == `,` && line[pos + 1] == ` ` {
				return pos + 1
			}
			if (line[pos] == `&` && line[pos + 1] == `&`)
				|| (line[pos] == `|` && line[pos + 1] == `|`) {
				if best_op == -1 { best_op = pos + 2 }
			}
		}
		if line[pos] == ` ` && best_space == -1 {
			best_space = pos
		}
	}
	if best_op != -1 { return best_op }
	if best_space != -1 { return best_space }
	return -1
}

fn leading_whitespace_len(line string) int {
	mut count := 0
	for i in 0 .. line.len {
		c := line[i]
		if c == `\t` || c == ` ` {
			count++
		} else {
			break
		}
	}
	return count
}

fn calc_cont_indent(line string, prefix_len int, cfg Config) int {
	tabs := if cfg.indent_style == .tabs {
		prefix_len
	} else {
		prefix_len / cfg.indent_width
	}
	trimmed := line.trim_space()
	if trimmed.ends_with('{') {
		return tabs + 2
	}
	return tabs + 1
}

fn (mut ctx FormatContext) run() {
	for i, tok in ctx.tokens {
		if tok.typ == .eof {
			break
		}

		if tok.typ == .newline {
			ctx.prev_newline = true
			continue
		}
		if ctx.pp_tok(tok, i) {
			continue
		}

		if tok.typ == .line_comment {
			ctx.write_newline()
			ctx.write_indent()
			ctx.sb.write_string(tok.value)
			ctx.sb.write_string('\n')
			ctx.line_start = true
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .block_comment {
			if ctx.line_start {
				ctx.write_indent()
			} else {
				ctx.sb.write_string(' ')
			}
			ctx.sb.write_string(tok.value)
			if tok.value.contains('\n') && !tok.value.ends_with('\n') {
				ctx.sb.write_string('\n')
				ctx.line_start = true
			} else {
				ctx.line_start = false
			}
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .rbrace {
			if ctx.skip_rbrace {
				ctx.skip_rbrace = false
				ctx.prev_tok = tok
				continue
			}
			ctx.indent_lvl--
			ctx.brace_depth--
			ctx.write_newline()
			ctx.write_indent()
			ctx.sb.write_string('}')

			nop := ctx.peek(i)
			if nop == .semicolon || nop == .comma || nop == .identifier || nop == .number {
				ctx.line_start = false
			} else if nop == .kw_else || nop == .kw_while || nop == .dot || nop == .arrow
				|| nop == .operator || nop == .lparen || nop == .lbracket {
				ctx.sb.write_string(' ')
				ctx.line_start = false
			} else {
				ctx.sb.write_string('\n')
				ctx.line_start = true
			}
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .semicolon {
			ctx.sb.write_string(';')
			if ctx.in_for && ctx.paren_depth > 0 {
				ctx.sb.write_string(' ')
			} else {
				nop := ctx.peek(i)
				mut sep := '\n'
				if ctx.prev_tok.typ == .rbrace && ctx.indent_lvl == 0 && nop != .eof {
					sep = '\n\n'
				}
				ctx.sb.write_string(sep)
				ctx.line_start = true
			}
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .lbrace {
			if !ctx.line_start {
				if (ctx.prev_tok.typ == .rparen && !ctx.last_cast_paren)
					|| ctx.prev_tok.typ == .identifier
					|| ctx.prev_tok.typ == .kw_else || ctx.prev_tok.typ == .kw_do {
					ctx.sb.write_string(' ')
				}
			}
			nop := ctx.peek(i)
			if nop == .rbrace {
				ctx.sb.write_string('{}')
				ctx.skip_rbrace = true
				ctx.line_start = false
			} else {
				ctx.sb.write_string('{')
				ctx.indent_lvl++
				ctx.brace_depth++
				ctx.sb.write_string('\n')
				ctx.line_start = true
			}
			ctx.last_cast_paren = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ in [.kw_if, .kw_while, .kw_for, .kw_switch, .kw_return] {
			if !((tok.typ == .kw_while && ctx.prev_tok.typ == .rbrace)
				|| ctx.prev_tok.typ == .kw_else) {
				ctx.write_newline()
				ctx.write_indent()
			}
			ctx.sb.write_string(tok.value)
			ctx.sb.write_string(' ')
			ctx.line_start = false
			ctx.prev_tok = tok
			if tok.typ == .kw_for {
				ctx.in_for = true
			}
			continue
		}

		if tok.typ == .kw_else {
			nop := ctx.peek(i)
			if ctx.prev_tok.typ != .rbrace {
				ctx.write_newline()
				ctx.write_indent()
			}
			ctx.sb.write_string('else')
			match nop {
				.kw_if {
					ctx.sb.write_string(' ')
				}
				.lbrace {}
				else {
					ctx.sb.write_string('\n')
					ctx.line_start = true
				}
			}

			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .kw_do {
			ctx.write_newline()
			ctx.write_indent()
			ctx.sb.write_string('do')
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .lparen {
			space := ctx.prev_tok.typ != .identifier && ctx.prev_tok.typ != .rparen
				&& ctx.prev_tok.typ != .rbrace && ctx.prev_tok.typ != .lbracket
				&& ctx.prev_tok.typ != .rbracket && ctx.prev_tok.typ != .number
				&& ctx.prev_tok.typ != .string_lit && ctx.prev_tok.typ != .char_lit
				&& ctx.prev_tok.typ != .kw_sizeof && ctx.prev_tok.typ != .kw_return
				&& ctx.prev_tok.typ != .kw_if && ctx.prev_tok.typ != .kw_while
				&& ctx.prev_tok.typ != .kw_for && ctx.prev_tok.typ != .kw_switch
				&& ctx.prev_tok.typ != .kw_do && ctx.prev_tok.typ != .colon
				&& ctx.prev_tok.typ != .operator
			if ctx.line_start {
				ctx.write_indent()
			} else if space {
				ctx.sb.write_string(' ')
			}
			outer_cast := ctx.paren_cast.len > 0 && ctx.paren_cast[ctx.paren_cast.len - 1]
			is_cast := outer_cast
				|| ctx.prev_tok.typ in [.operator, .lparen, .comma, .colon, .question, .dot, .arrow, .lbracket, .rbracket, .kw_return, .kw_sizeof, .kw_case, .kw_default]
			ctx.paren_cast << is_cast
			ctx.sb.write_string('(')
			ctx.paren_depth++
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .rparen {
			ctx.sb.write_string(')')
			ctx.paren_depth--
			if ctx.paren_depth <= 0 {
				ctx.in_for = false
				if ctx.paren_depth < 0 { ctx.paren_depth = 0 }
			}
			if ctx.paren_cast.len > 0 {
				ctx.last_cast_paren = ctx.paren_cast[ctx.paren_cast.len - 1]
				ctx.paren_cast = ctx.paren_cast[..ctx.paren_cast.len - 1]
			}
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .comma {
			ctx.sb.write_string(',')
			nop := ctx.peek(i)
			if ctx.brace_depth > 0 {
				ctx.sb.write_string('\n')
				ctx.line_start = true
			} else {
				if nop != .rparen && nop != .eof {
					ctx.sb.write_string(' ')
				}
				ctx.line_start = false
			}
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .kw_case {
			ctx.write_newline()
			if ctx.indent_lvl > 0 { ctx.indent_lvl-- }
			ctx.write_indent()
			ctx.sb.write_string('case ')
			ctx.line_start = false
			ctx.in_case = true
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .kw_default {
			ctx.write_newline()
			if ctx.indent_lvl > 0 { ctx.indent_lvl-- }
			ctx.write_indent()
			ctx.sb.write_string('default')
			ctx.in_case = true
			nop := ctx.peek(i)
			if nop != .colon {
				ctx.sb.write_string(' ')
			}
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .colon {
			if ctx.in_case {
				ctx.sb.write_string(':\n')
				ctx.line_start = true
				ctx.indent_lvl++
				ctx.in_case = false
			} else {
				ctx.sb.write_string(':')
				ctx.line_start = false
			}
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .question {
			ctx.sb.write_string(' ? ')
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .dot || tok.typ == .arrow {
			if ctx.line_start {
				ctx.write_indent()
			}
			ctx.sb.write_string(tok.value)
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .operator {
			space_before := !ctx.line_start && is_binary_op(tok.value)
				&& !(ctx.prev_tok.typ == .operator && !is_binary_op(ctx.prev_tok.value))
			if ctx.line_start {
				ctx.write_indent()
			} else if space_before {
				ctx.sb.write_string(' ')
			}
			ctx.sb.write_string(tok.value)
			if is_binary_op(tok.value) {
				ctx.sb.write_string(' ')
			}
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .lbracket {
			if ctx.line_start {
				ctx.write_indent()
			}
			ctx.sb.write_string('[')
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if tok.typ == .rbracket {
			ctx.sb.write_string(']')
			ctx.line_start = false
			ctx.prev_tok = tok
			continue
		}

		if ctx.line_start {
			ctx.write_indent()
		} else if needs_space_before(tok, ctx.prev_tok) {
			ctx.sb.write_string(' ')
		}

		ctx.sb.write_string(tok.value)
		ctx.line_start = false
		ctx.prev_tok = tok
	}

	if !ctx.line_start {
		ctx.sb.write_string('\n')
	}
}

fn (ctx &FormatContext) peek(i int) TokenType {
	for j in i + 1 .. ctx.tokens.len {
		t := ctx.tokens[j].typ
		if t != .newline {
			return t
		}
	}
	return .eof
}

fn (mut ctx FormatContext) pp_tok(tok Token, _ int) bool {
	if tok.typ !in [.pp_include, .pp_define, .pp_other] {
		return false
	}

	if !ctx.line_start {
		ctx.sb.write_string('\n')
	}

	ctx.sb.write_string(tok.value)

	if !tok.value.ends_with('\n') {
		ctx.sb.write_string('\n')
	}
	ctx.line_start = true
	ctx.prev_tok = tok
	return true
}

fn (mut ctx FormatContext) write_newline() {
	if !ctx.line_start {
		ctx.sb.write_string('\n')
		ctx.line_start = true
	}
}

fn (mut ctx FormatContext) write_indent() {
	if ctx.config.indent_style == .tabs {
		for _ in 0 .. ctx.indent_lvl {
			ctx.sb.write_string('\t')
		}
	} else {
		for _ in 0 .. ctx.indent_lvl * ctx.config.indent_width {
			ctx.sb.write_string(' ')
		}
	}
	ctx.line_start = false
}

fn is_word_type(t TokenType) bool {
	return t in [.identifier, .number, .string_lit, .char_lit, .kw_if, .kw_else, .kw_for, .kw_while,
		.kw_do, .kw_switch, .kw_return, .kw_break, .kw_continue, .kw_struct, .kw_union, .kw_enum,
		.kw_typedef, .kw_static, .kw_extern, .kw_const, .kw_void, .kw_char, .kw_int, .kw_short,
		.kw_long, .kw_float, .kw_double, .kw_signed, .kw_unsigned, .kw_sizeof, .kw_auto, .kw_register,
		.kw_volatile, .kw_goto]
}

fn needs_space_before(tok Token, prev Token) bool {
	if prev.typ == .eof || prev.typ == .newline || prev.typ == .lparen || prev.typ == .lbracket
		|| prev.typ == .kw_return || prev.typ == .kw_sizeof {
		return false
	}
	if tok.typ == .semicolon || tok.typ == .comma || tok.typ == .rparen || tok.typ == .rbracket {
		return false
	}
	if prev.typ == .comma || prev.typ == .lparen || prev.typ == .lbracket || prev.typ == .operator
		|| prev.typ == .semicolon {
		return false
	}
	if prev.typ == .identifier && tok.typ == .lparen {
		return false
	}
	if prev.typ == .rparen && (tok.typ == .lparen || tok.typ == .identifier) {
		return false
	}
	if is_word_type(prev.typ) && is_word_type(tok.typ) {
		return true
	}
	if prev.typ == .rparen && tok.typ == .lbrace {
		return true
	}
	if prev.typ == .rbrace || prev.typ == .rbracket || prev.typ == .rparen {
		if tok.typ != .lparen {
			return true
		}
	}
	if prev.typ == .identifier && tok.typ != .lparen && tok.typ != .lbracket
		&& tok.typ != .semicolon {
		return true
	}
	if tok.typ == .identifier && prev.typ != .dot && prev.typ != .arrow {
		return true
	}
	return false
}
