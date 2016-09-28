# readelf-d

readelf implementation written in D.

## Usage:

```console
$ ./readelf-d -H
readelf-d
USAGE:
 readelf-d [OPTION] elf-file..
 Display information about the contents of ELF format files
 Options are:
  -a --all               Equivalent to: -h -S -s
  -h --file-header       Display the ELF file header
  -S --section-headers   Display sections' headers
  -s --symbols           Display the symbol table
  -H --help              Display this information
 ```
