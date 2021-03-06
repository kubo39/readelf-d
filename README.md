# readelf-d [![Build Status](https://secure.travis-ci.org/kubo39/readelf-d.svg?branch=master)](http://travis-ci.org/kubo39/readelf-d)

readelf implementation written in D.

## Usage:

```console
$ ./readelf-d --help
readelf-d
USAGE:
 readelf-d [OPTION] elf-file..
 Display information about the contents of ELF format files
 Options are:
  -a --all               Equivalent to: -h -l -S -n -s
  -h --file-header       Display the ELF file header
  -l --program-headers   Display the program headers
  -S --section-headers   Display sections' headers
  --dyn-syms             Display the dynamic symbol table
  -n --notes             Display core notes
  -e --headers           Equivalent to: -h -l -S
  -s --symbols           Display the symbol table
  --debug-dump[=abbrev]  Display the contents of DWARF2 debug sections
  -H --help              Display this information
```
