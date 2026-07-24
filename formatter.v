module main

import strings

struct FormatContext {
	config Config
	tokens []Token
mut:
	sb                 strings.Builder
	indent_lvl         int
	brace_depth        int
	line_start         bool
	prev_tok           Token
	prev_prev_tok      Token
	paren_depth        int
	in_for             bool
	in_case            bool
	prev_newline       bool
	skip_rbrace        bool
	paren_cast         []bool
	last_cast_paren    bool
	next_is_struct     bool
	next_is_enum       bool
	struct_brace       []bool
	enum_brace         []bool
	init_brace         []bool
	newline_count      int
	id_at_line_start   bool
	last_was_cast      bool
	wrote_blank_line   bool
	expect_body        bool
	expect_control     bool
	body_depth         int
	inline_init_depth  int
	inline_init_rbrace bool
	paren_func_call    []bool
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
		trimmed := line.trim_space()
		is_comment := trimmed.starts_with('//')
		comment_prefix := if is_comment {
			line[..prefix] + '// '
		} else {
			''
		}
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
			if is_comment {
				remaining = comment_prefix + remaining[best_pos..].trim_left(' ')
			} else {
				remaining = cont_str + remaining[best_pos..].trim_left(' ')
			}
		}
		result << remaining
	}
	return result.join('\n')
}

fn pos_in_string(line string, pos int) bool {
	mut in_str := false
	for i := 0; i < pos; i++ {
		if line[i] == `"` && !(i > 0 && line[i - 1] == `\\`) {
			in_str = !in_str
		}
	}
	return in_str
}

fn find_break_pos(line string, prefix_len int, max_len int) int {
	end := if max_len < line.len { max_len } else { line.len - 1 }
	mut best_op := -1
	mut best_space := -1
	for pos := end; pos > prefix_len; pos-- {
		if pos_in_string(line, pos) { continue
		 }
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
			ctx.newline_count++
			continue
		}
		if ctx.pp_tok(tok, i) {
			continue
		}
		wrote_bl := ctx.wrote_blank_line
		ctx.wrote_blank_line = false
		prev_blank_lines := ctx.newline_count
		ctx.newline_count = 0
		if ctx.line_start && prev_blank_lines > 1 && tok.typ != .rbrace && !wrote_bl
			&& !(ctx.prev_tok.typ == .rbrace && ctx.indent_lvl == 0) {
			ctx.sb.write_string('\n')
		}

		if ctx.expect_body && tok.typ != .lbrace {
			if !ctx.line_start {
				ctx.sb.write_string('\n')
			}
			ctx.body_depth++
			ctx.expect_body = false
			ctx.line_start = true
		}

		if tok.typ == .line_comment {
			if ctx.line_start {
				ctx.write_indent()
			} else if prev_blank_lines > 1 {
				ctx.sb.write_string('\n\n')
				ctx.write_indent()
			} else if prev_blank_lines > 0 {
				ctx.sb.write_string('\n')
				ctx.write_indent()
			} else {
				ctx.sb.write_string(' ')
			}
			ctx.sb.write_string(tok.value)
			ctx.sb.write_string('\n')
			ctx.line_start = true
			ctx.advance(tok)
			continue
		}

		if tok.typ == .block_comment {
			was_line_start := ctx.line_start
			if ctx.line_start {
				ctx.write_indent()
			} else {
				ctx.sb.write_string(' ')
			}
			ctx.sb.write_string(tok.value)
			if was_line_start || (tok.value.contains('\n') && !tok.value.ends_with('\n')) {
				ctx.sb.write_string('\n')
				ctx.line_start = true
			} else {
				ctx.line_start = false
			}
			ctx.advance(tok)
			continue
		}

		if tok.typ == .rbrace {
			if ctx.skip_rbrace {
				ctx.skip_rbrace = false
				if ctx.struct_brace.len > 0 { ctx.struct_brace.pop() }
				if ctx.enum_brace.len > 0 { ctx.enum_brace.pop() }
				if ctx.init_brace.len > 0 { ctx.init_brace.pop() }
				ctx.advance(tok)
				continue
			}
			if ctx.inline_init_depth > 0 {
				ctx.inline_init_depth--
				if ctx.init_brace.len > 0 { ctx.init_brace.pop() }
				ctx.sb.write_string('}')
				ctx.line_start = false
				ctx.inline_init_rbrace = true
				ctx.advance(tok)
				continue
			}
			is_struct := if ctx.struct_brace.len > 0 { ctx.struct_brace.pop() } else { false }
			if ctx.enum_brace.len > 0 { ctx.enum_brace.pop() }
			is_init_brace := if ctx.init_brace.len > 0 { ctx.init_brace.pop() } else { false }
			ctx.next_is_struct = false
			ctx.next_is_enum = false
			ctx.last_was_cast = false
			ctx.last_cast_paren = false
			ctx.indent_lvl--
			ctx.brace_depth--
			ctx.write_newline()
			ctx.write_indent()
			ctx.sb.write_string('}')

			nop := ctx.peek(i)
			if nop == .semicolon || nop == .comma || nop == .number || nop == .rparen {
				ctx.line_start = false
			} else if nop == .identifier && is_struct {
				ctx.line_start = false
			} else if nop == .line_comment && ctx.indent_lvl > 0 {
				if ctx.tokens.len > i + 1 && ctx.tokens[i + 1].typ == .line_comment {
					ctx.line_start = false
				} else {
					ctx.sb.write_string('\n')
					ctx.line_start = true
				}
			} else if nop == .kw_else || nop == .kw_while || nop == .dot
				|| nop == .arrow
				|| (nop == .operator && (is_struct || is_init_brace))
				|| nop == .lparen || nop == .lbracket {
				ctx.sb.write_string(' ')
				ctx.line_start = false
			} else if ctx.indent_lvl == 0 && nop != .eof {
				ctx.sb.write_string('\n\n')
				ctx.line_start = true
				ctx.wrote_blank_line = true
			} else {
				ctx.sb.write_string('\n')
				ctx.line_start = true
			}
			ctx.advance(tok)
			continue
		}

		if tok.typ == .semicolon {
			if ctx.line_start {
				ctx.write_indent()
			}
			ctx.next_is_struct = false
			ctx.next_is_enum = false
			if !(ctx.in_for && ctx.paren_depth > 0) {
				ctx.body_depth = 0
			}
			ctx.sb.write_string(';')
			if ctx.in_for && ctx.paren_depth > 0 {
				ctx.sb.write_string(' ')
			} else {
				nop := ctx.peek(i)
				immediate_is_nl := i + 1 < ctx.tokens.len && ctx.tokens[i + 1].typ == .newline
				if nop == .line_comment && !immediate_is_nl {
					ctx.line_start = false
				} else {
					mut sep := '\n'
					if ctx.prev_tok.typ == .rbrace && ctx.indent_lvl == 0 && nop != .eof
						&& !ctx.inline_init_rbrace {
						sep = '\n\n'
						ctx.wrote_blank_line = true
					}
					ctx.inline_init_rbrace = false
					ctx.sb.write_string(sep)
					ctx.line_start = true
				}
			}
			ctx.advance(tok)
			continue
		}

		if tok.typ == .lbrace {
			ctx.expect_body = false
			is_struct_def := ctx.next_is_struct && (ctx.prev_tok.typ == .identifier
				|| ctx.prev_tok.typ == .kw_struct || ctx.prev_tok.typ == .kw_union
				|| ctx.prev_tok.typ == .kw_enum)
			is_enum_def := ctx.next_is_enum
				&& (ctx.prev_tok.typ == .identifier || ctx.prev_tok.typ == .kw_enum)
			is_init := ctx.prev_tok.typ in [.comma, .lparen, .lbrace]
				|| (ctx.prev_tok.typ == .operator && ctx.prev_tok.value == '=')
				|| ctx.last_was_cast
			inside_init_arr := is_init && ctx.init_brace.len > 0 && ctx.init_brace.last()
			ctx.last_was_cast = false
			ctx.struct_brace << is_struct_def
			ctx.enum_brace << is_enum_def
			ctx.init_brace << is_init
			ctx.next_is_struct = false
			ctx.next_is_enum = false
			if !ctx.line_start {
				if (ctx.prev_tok.typ == .rparen && !ctx.last_cast_paren)
					|| ctx.prev_tok.typ == .identifier
					|| ctx.prev_tok.typ in [.kw_else, .kw_do, .kw_struct, .kw_union, .kw_enum] {
					ctx.sb.write_string(' ')
				}
			}
			nop := ctx.peek(i)
			if nop == .rbrace {
				ctx.sb.write_string('{}')
				ctx.skip_rbrace = true
				ctx.line_start = false
			} else if is_init && nop in [.number, .identifier, .string_lit, .char_lit] {
				mut is_single := false
				for j in i + 1 .. ctx.tokens.len {
					t := ctx.tokens[j].typ
					if t == .newline { continue
					 }
					if t in [.number, .identifier, .string_lit, .char_lit] {
						for k in j + 1 .. ctx.tokens.len {
							t2 := ctx.tokens[k].typ
							if t2 == .newline { continue
							 }
							if t2 == .rbrace { is_single = true }
							break
						}
					}
					break
				}
				if is_single || inside_init_arr {
					if ctx.line_start {
						ctx.write_indent()
					}
					ctx.sb.write_string('{')
					ctx.inline_init_depth++
					ctx.line_start = false
				} else {
					if ctx.line_start {
						ctx.write_indent()
					}
					ctx.sb.write_string('{')
					ctx.indent_lvl++
					ctx.brace_depth++
					ctx.sb.write_string('\n')
					ctx.line_start = true
				}
			} else {
				if ctx.line_start {
					ctx.write_indent()
				}
				ctx.sb.write_string('{')
				ctx.indent_lvl++
				ctx.brace_depth++
				ctx.sb.write_string('\n')
				ctx.line_start = true
			}
			ctx.last_cast_paren = false
			ctx.advance(tok)
			continue
		}

		if tok.typ in [.kw_if, .kw_while, .kw_for, .kw_switch] {
			is_dowhile := tok.typ == .kw_while && ctx.prev_tok.typ == .rbrace
			if !(is_dowhile || ctx.prev_tok.typ == .kw_else) {
				ctx.write_newline()
				ctx.write_indent()
			}
			ctx.sb.write_string(tok.value)
			ctx.sb.write_string(' ')
			ctx.line_start = false
			ctx.advance(tok)
			if tok.typ == .kw_for {
				ctx.in_for = true
			}
			if !is_dowhile && tok.typ in [.kw_if, .kw_while, .kw_for] {
				ctx.expect_control = true
			}
			continue
		}

		if tok.typ == .kw_return {
			ctx.write_newline()
			ctx.write_indent()
			ctx.sb.write_string(tok.value)
			nop := ctx.peek(i)
			if nop != .semicolon {
				ctx.sb.write_string(' ')
			}
			ctx.line_start = false
			ctx.advance(tok)
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

			if nop != .lbrace && nop != .kw_if {
				ctx.expect_body = true
			}
			if nop == .kw_if || nop == .lbrace {
				ctx.line_start = false
			}
			ctx.advance(tok)
			continue
		}

		if tok.typ == .kw_do {
			ctx.write_newline()
			ctx.write_indent()
			ctx.sb.write_string('do')
			ctx.line_start = false
			ctx.advance(tok)
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
				&& ctx.prev_tok.typ != .comma && ctx.prev_tok.typ != .operator
				&& ctx.prev_tok.typ != .lparen
			in_struct := ctx.struct_brace.len > 0 && ctx.struct_brace.last()
			is_func_ptr :=
				ctx.prev_tok.typ in [.identifier, .kw_void, .kw_char, .kw_int, .kw_float, .kw_double, .kw_long, .kw_short, .kw_signed, .kw_unsigned]
				&& (ctx.brace_depth == 0 || in_struct) && ctx.prev_prev_tok.typ !in [.arrow, .dot]
				&& ctx.peek(i) == .operator
			if ctx.line_start {
				ctx.write_indent()
				if is_func_ptr {
					ctx.sb.write_string(' ')
				}
			} else if space || is_func_ptr {
				ctx.sb.write_string(' ')
			}
			outer_cast := ctx.paren_cast.len > 0 && ctx.paren_cast[ctx.paren_cast.len - 1]
			mut is_cast := (outer_cast && ctx.prev_tok.typ != .kw_sizeof)
				|| ctx.prev_tok.typ in [.operator, .lparen, .comma, .colon, .question, .dot, .arrow, .lbracket, .rbracket, .rparen, .kw_return, .kw_case, .kw_default]
			if is_cast && !is_type_like_paren(ctx.tokens, i) {
				is_cast = false
			}
			ctx.paren_cast << is_cast
			ctx.paren_func_call << (ctx.prev_tok.typ == .identifier)
			ctx.sb.write_string('(')
			ctx.paren_depth++
			ctx.line_start = false
			ctx.advance(tok)
			continue
		}

		if tok.typ == .rparen {
			ctx.next_is_struct = false
			ctx.next_is_enum = false
			ctx.sb.write_string(')')
			ctx.paren_depth--
			is_func_call := ctx.paren_func_call.len > 0 && ctx.paren_func_call.pop()
			if ctx.paren_depth <= 0 {
				if ctx.expect_control {
					ctx.expect_body = true
					ctx.expect_control = false
				} else {
					nop := ctx.peek(i)
					if nop in [.kw_if, .kw_while, .kw_for, .kw_switch, .kw_do, .lbrace]
						|| (nop == .identifier && is_func_call) {
						ctx.expect_body = true
					}
				}
				ctx.in_for = false
				if ctx.paren_depth < 0 { ctx.paren_depth = 0 }
			}
			if ctx.paren_cast.len > 0 {
				ctx.last_cast_paren = ctx.paren_cast[ctx.paren_cast.len - 1]
				ctx.paren_cast = ctx.paren_cast[..ctx.paren_cast.len - 1]
			}
			ctx.last_was_cast = ctx.last_cast_paren
			ctx.line_start = false
			ctx.advance(tok)
			continue
		}

		if tok.typ == .comma {
			ctx.sb.write_string(',')
			nop := ctx.peek(i)
			in_init_brace := ctx.init_brace.len > 0 && ctx.init_brace.last()
			in_enum_brace := ctx.enum_brace.len > 0 && ctx.enum_brace.last()
			write_newline := (ctx.brace_depth > 0 && in_init_brace && ctx.inline_init_depth == 0)
				|| in_enum_brace
			if write_newline {
				ctx.sb.write_string('\n')
				ctx.line_start = true
			} else {
				if nop !in [.rparen, .rbrace, .eof] {
					ctx.sb.write_string(' ')
				}
				ctx.line_start = false
			}
			ctx.advance(tok)
			continue
		}

		if tok.typ == .kw_case {
			ctx.write_newline()
			if ctx.indent_lvl > 0 { ctx.indent_lvl-- }
			ctx.write_indent()
			ctx.sb.write_string('case ')
			ctx.line_start = false
			ctx.in_case = true
			ctx.advance(tok)
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
			ctx.advance(tok)
			continue
		}

		if tok.typ == .colon {
			if ctx.in_case {
				ctx.sb.write_string(':\n')
				ctx.line_start = true
				ctx.indent_lvl++
				ctx.in_case = false
			} else if ctx.id_at_line_start && ctx.prev_tok.typ == .identifier {
				ctx.sb.write_string(':\n')
				ctx.line_start = true
			} else {
				ctx.sb.write_string(' :')
				ctx.line_start = false
			}
			ctx.advance(tok)
			continue
		}

		if tok.typ == .question {
			ctx.sb.write_string(' ?')
			ctx.line_start = false
			ctx.advance(tok)
			continue
		}

		if tok.typ == .dot || tok.typ == .arrow {
			if ctx.line_start {
				ctx.write_indent()
			}
			ctx.sb.write_string(tok.value)
			ctx.line_start = false
			ctx.advance(tok)
			continue
		}

		if tok.typ == .operator {
			is_binary := is_binary_op(tok.value)
			can_be_unary := tok.value in ['*', '&', '+', '-', '~', '!']
			is_struct_star := tok.value == '*' && ctx.prev_tok.typ == .identifier
				&& (ctx.next_is_struct || (ctx.id_at_line_start && ctx.peek(i) in [.identifier, .rparen, .rbracket, .kw_const, .kw_volatile]
				&& (ctx.paren_depth == 0 || ctx.peek(i) != .identifier)))
			is_ptr_dec := tok.value in ['*', '&'] && ctx.prev_tok.typ == .identifier
				&& !is_struct_star && is_ptr_lookahead(ctx.tokens, i)
			nop := ctx.peek(i)
			is_cast_rparen := ctx.last_was_cast && ctx.prev_tok.typ == .rparen && can_be_unary
				&& nop !in [.number, .string_lit, .char_lit]
			in_struct_decl := ctx.struct_brace.len > 0 && ctx.struct_brace.last()
			is_ptr_param := tok.value == '*' && is_word_type(ctx.prev_tok.typ) && (in_struct_decl
				|| (ctx.brace_depth == 0 && (ctx.paren_depth == 0
				|| is_func_param_ctx(ctx.tokens, i))))
				&& nop in [.identifier, .kw_const, .kw_volatile, .operator]
			always_unary := tok.value in ['!', '~']
			space_before_always_unary := always_unary && !ctx.line_start
				&& !(ctx.prev_tok.typ in [.lparen, .lbracket]
				|| (ctx.prev_tok.typ == .operator && !is_binary_op(ctx.prev_tok.value)))
			space_before := !ctx.line_start && !(ctx.prev_tok.typ == .operator
				&& !is_binary_op(ctx.prev_tok.value) && can_be_unary) && !(can_be_unary
				&& is_unary_prefix_ctx(ctx.prev_tok.typ)) && !is_cast_rparen
				&& (is_binary || space_before_always_unary)
			is_truly_binary := is_binary && !(can_be_unary && is_unary_op_ctx(ctx.prev_tok.typ))
				&& !is_struct_star && !is_ptr_dec && !is_ptr_param && !(ctx.line_start
				&& can_be_unary) && !is_cast_rparen
			if ctx.line_start {
				ctx.write_indent()
			} else if space_before {
				ctx.sb.write_string(' ')
			}
			ctx.sb.write_string(tok.value)
			if is_truly_binary {
				ctx.sb.write_string(' ')
			}
			ctx.line_start = false
			ctx.advance(tok)
			continue
		}

		if tok.typ == .lbracket {
			if ctx.line_start {
				ctx.write_indent()
			}
			ctx.sb.write_string('[')
			ctx.line_start = false
			ctx.advance(tok)
			continue
		}

		if tok.typ == .rbracket {
			ctx.sb.write_string(']')
			ctx.line_start = false
			ctx.advance(tok)
			continue
		}

		if tok.typ == .kw_enum {
			ctx.next_is_struct = true
			ctx.next_is_enum = true
		} else if tok.typ in [.kw_struct, .kw_union] {
			ctx.next_is_struct = true
		}

		was_line_start := ctx.line_start
		if ctx.line_start {
			if tok.typ == .identifier && ctx.peek(i) == .colon {
				if ctx.indent_lvl > 0 {
					ctx.indent_lvl--
					ctx.write_indent()
					ctx.indent_lvl++
				}
			} else {
				ctx.write_indent()
			}
		} else if tok.typ == .string_lit && ctx.prev_tok.typ == .string_lit && prev_blank_lines > 0 {
			ctx.sb.write_string('\n')
			cont_total := ctx.indent_lvl + ctx.body_depth + 1
			if ctx.config.indent_style == .tabs {
				ctx.sb.write_string('\t'.repeat(cont_total))
			} else {
				ctx.sb.write_string(' '.repeat(cont_total * ctx.config.indent_width))
			}
		} else if needs_space_before(tok, ctx.prev_tok) && !(ctx.prev_tok.typ == .rparen
			&& ctx.last_was_cast) {
			ctx.sb.write_string(' ')
		}

		ctx.sb.write_string(tok.value)
		ctx.id_at_line_start = tok.typ == .identifier && (was_line_start
			|| ctx.prev_tok.typ in [.kw_static, .kw_extern, .kw_typedef, .kw_const, .kw_volatile]
			|| (ctx.prev_tok.typ == .lparen
			&& ctx.prev_prev_tok.typ !in [.kw_if, .kw_while, .kw_for, .kw_switch, .rparen])
			|| (ctx.prev_tok.typ == .comma && ctx.paren_depth > 0))
		ctx.line_start = false
		ctx.advance(tok)
	}

	if !ctx.line_start {
		ctx.sb.write_string('\n')
	}
}

fn (mut ctx FormatContext) advance(tok Token) {
	ctx.prev_prev_tok = ctx.prev_tok
	ctx.prev_tok = tok
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

	if ctx.newline_count > 1 {
		ctx.sb.write_string('\n')
	}
	ctx.newline_count = 0
	if ctx.wrote_blank_line { ctx.wrote_blank_line = false }

	ctx.sb.write_string(tok.value)

	if !tok.value.ends_with('\n') {
		ctx.sb.write_string('\n')
	}
	ctx.line_start = true
	ctx.advance(tok)
	return true
}

fn (mut ctx FormatContext) write_newline() {
	if !ctx.line_start {
		ctx.sb.write_string('\n')
		ctx.line_start = true
	}
}

fn (mut ctx FormatContext) write_indent() {
	total := ctx.indent_lvl + ctx.body_depth
	if ctx.config.indent_style == .tabs {
		ctx.sb.write_string('\t'.repeat(total))
	} else {
		ctx.sb.write_string(' '.repeat(total * ctx.config.indent_width))
	}
	ctx.line_start = false
}

fn is_unary_prefix_ctx(prev TokenType) bool {
	return prev in [.lparen, .lbracket, .comma, .operator, .semicolon, .lbrace, .rbrace, .kw_return,
		.kw_sizeof, .kw_case, .kw_default]
}

fn is_unary_op_ctx(prev TokenType) bool {
	return prev !in [.identifier, .rparen, .rbracket, .rbrace, .number, .string_lit, .char_lit]
}

fn is_type_like_paren(tokens []Token, i int) bool {
	mut depth := 1
	mut bracket_depth := 0
	for j := i + 1; j < tokens.len; j++ {
		t := tokens[j].typ
		if t == .newline || t == .line_comment || t == .block_comment {
			continue
		}
		if t == .lparen {
			depth++
			continue
		}
		if t == .rparen {
			depth--
			if depth == 0 {
				break
			}
			continue
		}
		if t == .lbracket {
			bracket_depth++
			continue
		}
		if t == .rbracket {
			bracket_depth--
			continue
		}
		if depth == 1 && bracket_depth == 0 {
			if t in [.number, .string_lit, .char_lit, .dot, .arrow]
				|| (t == .operator && tokens[j].value !in ['*', '&']) {
				return false
			}
		}
	}
	return true
}

fn is_ptr_lookahead(tokens []Token, i int) bool {
	for j in i + 1 .. tokens.len {
		t := tokens[j].typ
		if t == .newline {
			continue
		}
		if t != .identifier { return false }
		for k in j + 1 .. tokens.len {
			t2 := tokens[k].typ
			if t2 == .newline {
				continue
			}
			return t2 == .operator && tokens[k].value == '='
		}
	}
	return false
}

fn is_func_param_ctx(tokens []Token, i int) bool {
	// Scan forward from i to find the matching ')' at the current paren depth.
	// Then check if what follows is '{' (function definition) or ';' (function declaration)
	// AND the paren content looks like a parameter list (type-like).
	mut rparen_idx := -1
	mut depth := 0
	for j := i + 1; j < tokens.len; j++ {
		t := tokens[j].typ
		if t == .lparen { depth++ }
		if t == .rparen {
			if depth == 0 {
				rparen_idx = j
				break
			}
			depth--
		}
	}
	if rparen_idx == -1 { return false }
	// Find the matching '(' for this context by scanning backward
	mut lparen_idx := -1
	depth = 0
	for j := i; j >= 0; j-- {
		t := tokens[j].typ
		if t == .rparen { depth++ }
		if t == .lparen {
			if depth == 0 {
				lparen_idx = j
				break
			}
			depth--
		}
	}
	if lparen_idx == -1 { return false }
	// Check what follows the ')'
	mut tok_after := TokenType.eof
	for k := rparen_idx + 1; k < tokens.len; k++ {
		if tokens[k].typ == .newline { continue
		 }
		tok_after = tokens[k].typ
		break
	}
	if tok_after !in [TokenType.lbrace, TokenType.semicolon] { return false }
	// Verify paren content is type-like (not an expression)
	return is_type_like_paren(tokens, lparen_idx)
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
		|| prev.typ == .lbrace || prev.typ == .kw_return || prev.typ == .kw_sizeof {
		return false
	}
	if prev.typ in [.kw_case, .kw_default] {
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
	if prev.typ == .rparen
		&& (tok.typ == .lparen || tok.typ == .identifier || tok.typ == .kw_sizeof) {
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
	if prev.typ == .question && tok.typ != .semicolon {
		return true
	}
	if prev.typ == .colon && tok.typ != .semicolon {
		return true
	}
	return false
}
