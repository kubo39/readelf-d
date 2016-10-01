# readelf-d

readelf implementation written in D.

## Usage:

```console
$ ./readelf-d --help
readelf-d
USAGE:
 readelf-d [OPTION] elf-file..
 Display information about the contents of ELF format files
 Options are:
  -a --all               Equivalent to: -h -l -S -s
  -h --file-header       Display the ELF file header
  -l --program-headers   Display the program headers
  -S --section-headers   Display sections' headers
  -e --headers           Equivalent to: -h -l -S
  -s --symbols           Display the symbol table
  -H --help              Display this information
 ```
