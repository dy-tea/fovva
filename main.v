module main

import os
import flag

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('fovva')
	fp.version('0.0.0')
	fp.description('C code formatter')
	fp.skip_executable()
	fp.arguments_description('[files...]')

	max_line_len := fp.int('max-line-len', `m`, 100, 'maximum line length')
	indent_style_str := fp.string('indent', 0, 'tabs', 'indentation style (tabs|spaces)')
	indent_width := fp.int('indent-width', `w`, 8, 'indentation width')
	do_sort_includes := fp.bool('sort-includes', 0, true, 'sort include directives')
	in_place := fp.bool('in-place', `i`, false, 'format file in-place')
	recursive := fp.bool('recursive', `r`, false,
		'recursively format .c and .h files in directories')

	extra_args := fp.finalize() or {
		eprintln(fp.usage())
		exit(1)
	}

	cfg := Config{
		max_line_len:  max_line_len
		sort_includes: do_sort_includes
		indent_style:  if indent_style_str == 'spaces' {
			.spaces
		} else {
			.tabs
		}
		indent_width:  indent_width
	}

	mut paths := extra_args.clone()

	if recursive {
		mut expanded := []string{}
		for arg in extra_args {
			if os.is_dir(arg) {
				expanded << collect_c_files(arg)
			} else {
				expanded << arg
			}
		}
		paths = expanded.clone()
	}

	if paths.len == 0 {
		source_lines := os.get_lines()
		source := source_lines.join('\n') + '\n'
		formatted := format(source, cfg)
		print(formatted)
		return
	}

	for path in paths {
		source := os.read_file(path) or {
			eprintln('error: failed to read ${path}')
			exit(1)
		}
		formatted := format(source, cfg)
		if in_place {
			os.write_file(path, formatted) or {
				eprintln('error: failed to write ${path}')
				exit(1)
			}
		} else {
			print(formatted)
		}
	}
}

fn collect_c_files(path string) []string {
	mut result := []string{}
	items := os.ls(path) or { return result }
	for item in items {
		full := os.join_path(path, item)
		if os.is_dir(full) {
			result << collect_c_files(full)
		} else if full.ends_with('.c') || full.ends_with('.h') {
			result << full
		}
	}
	return result
}
