# sdlfmt

```
Auto-formatter for SDLang files
Usage:
        sdlfmt [OPTIONS...] [--] FILENAMES...

 General options:
-i --inplace Edit files in place
-h    --help This help information.

Formatter options:
                  --end_of_line (lf|cr|crlf)
-t               --indent_style (tab|space)
                  --indent_size (default = 1 for tab, 4 for space)
     --whitespace_around_equals (default = false)
   --backslash_temp_indent_size (default = 2)

Use - as only file name if you want to read from stdin

By default, only a single file can be passed in as input and the formatted
output will be dumped to stdout. Use --inplace to be able to specify multiple
input files.
```