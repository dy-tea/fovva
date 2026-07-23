module main

struct IncludeLine {
	raw    string
	path   string
	is_sys bool
}

pub fn sort_includes(source string) string {
	mut lines := source.split('\n')

	// skip leading blank lines
	mut start := 0
	for start < lines.len && lines[start].trim_space() == '' {
		start++
	}
	if start >= lines.len || !lines[start].trim_space().starts_with('#include') {
		return source
	}

	// collect contiguous include block (blank lines allowed inside)
	mut includes := []IncludeLine{}
	mut last_inc_idx := -1
	mut idx := start
	for idx < lines.len {
		trimmed := lines[idx].trim_space()
		if trimmed == '' {
			idx++
			continue
		}
		if trimmed.starts_with('#include') {
			rest := trimmed['#include'.len..].trim_space()
			if rest.len > 0 {
				is_sys := rest.starts_with('<')
				path := rest.trim_left('<"').trim_right('>"')
				includes << IncludeLine{lines[idx], path, is_sys}
			}
			last_inc_idx = idx
			idx++
		} else {
			break
		}
	}

	if includes.len == 0 {
		return source
	}

	// if includes exist outside this top block, leave everything untouched
	for i in idx .. lines.len {
		if lines[i].trim_space().starts_with('#include') {
			return source
		}
	}

	// build: leading lines + sorted includes + trailing lines
	mut result := []string{}
	result << lines[..start]
	result << includes.filter(it.is_sys).sorted(|a, b| a.path < b.path).map(|inc| inc.raw)
	result << includes.filter(!it.is_sys).sorted(|a, b| a.path < b.path).map(|inc| inc.raw)
	result << lines[last_inc_idx + 1..]
	return result.join('\n')
}
