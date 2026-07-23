# fovva

C formatter written in V following the [wlroots style](https://gitlab.freedesktop.org/wlroots/wlroots/-/blob/master/CONTRIBUTING.md?ref_type=heads#style-reference).

### Building

Install the [V compiler](https://vlang.io/), and run `v -prod .` to build for release.

### Options

By default, stdin will be used as input. So you can pipe in text, e.g. `cat main.c | fovva` which will print to stdout. You can use the in-place option (`-i`) to format and save a file, e.g. `fovva -i main.c`.

```
Usage: fovva [options] [files...]

Description: C code formatter

Options:
  -m, --max-line-len <int>  maximum line length (default 100)
  --indent <string>         indentation style (tabs|spaces) (default "tabs")
  -w, --indent-width <int>  indentation width (default 8)
  --sort-includes           sort include directives (default true)
  -i, --in-place            format file in-place (default false)
  -h, --help                display this help and exit
  --version                 output version information and exit
```
