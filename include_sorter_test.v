module main

fn test_sort_includes_basic() {
	input := '#include "zlib.h"\n#include "alib.h"\n#include <stdlib.h>\n#include <assert.h>'
	result := sort_includes(input)
	lines := result.split('\n')
	assert lines[0].contains('<assert.h>')
	assert lines[1].contains('<stdlib.h>')
	assert lines[2].contains('"alib.h"')
	assert lines[3].contains('"zlib.h"')
}

fn test_sort_includes_no_includes() {
	input := 'int x;\nint y;'
	result := sort_includes(input)
	assert result == input
}

fn test_sort_includes_empty_input() {
	result := sort_includes('')
	assert result == ''
}

fn test_sort_includes_only_local() {
	input := '#include "z.h"\n#include "a.h"'
	result := sort_includes(input)
	lines := result.split('\n')
	assert lines[0].contains('"a.h"')
	assert lines[1].contains('"z.h"')
}

fn test_sort_includes_only_system() {
	input := '#include <zlib.h>\n#include <assert.h>'
	result := sort_includes(input)
	lines := result.split('\n')
	assert lines[0].contains('<assert.h>')
	assert lines[1].contains('<zlib.h>')
}
