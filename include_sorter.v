module main

import arrays

struct IncludeLine {
	raw    string
	path   string
	is_sys bool
}

pub fn sort_includes(source string) string {
	mut lines := source.split('\n')
	mut include_indices := []int{}
	mut includes := []IncludeLine{}

	for i, raw in lines {
		trimmed := raw.trim_space()
		if trimmed.starts_with('#include') {
			rest := trimmed['#include'.len..].trim_space()
			if rest.len > 0 {
				is_sys := rest.starts_with('<')
				path := rest.trim_left('<"').trim_right('>"')
				includes << IncludeLine{raw, path, is_sys}
				include_indices << i
			}
		}
	}

	if includes.len == 0 {
		return source
	}

	// haskell
	return arrays.append(arrays.append(lines[0..include_indices[0]], arrays.append(includes.filter(it.is_sys).sorted(|a, b| a.path < b.path).map(|inc| inc.raw),
		includes.filter(!it.is_sys).sorted(|a, b| a.path < b.path).map(|inc| inc.raw))), lines[
		include_indices[include_indices.len - 1] + 1..lines.len]).join('\n')
}
