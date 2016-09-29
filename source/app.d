import elf;

import std.getopt;
import std.range;
import std.stdio;
import core.stdc.stdlib : exit;


void usage()
{
    writeln(`readelf-d
USAGE:
 readelf-d [OPTION] elf-file..
 Display information about the contents of ELF format files
 Options are:
  -a --all               Equivalent to: -h -S -s
  -h --file-header       Display the ELF file header
  -S --section-headers   Display sections' headers
  -s --symbols           Display the symbol table
  -H --help              Display this information
`);
}

void main(string[] args)
{
    scope(failure)
    {
        usage();
        exit(1);
    }

    bool help, all, fileHeader, sectionHeaders, symbols;

    getopt(
        args,
        std.getopt.config.caseSensitive,
        "a|all", &all,
        "h|file-header", &fileHeader,
        "S|section-headers", &sectionHeaders,
        "s|symbols", &symbols,
        "H|help", &help
        );

    if (help || args.length < 2)
    {
        usage();
        return;
    }

    if (all)
    {
        fileHeader = true;
        sectionHeaders = true;
        symbols = true;
    }

    ELF elf = ELF.fromFile(args[1]);

    if (fileHeader)
        printELFHeader(elf);
    if (sectionHeaders)
        printSectionHeaders(elf);
    if (symbols)
        printSymbols(elf);
}

void printELFHeader(ELF elf)
{
    writefln(`
ELF Header:
  Magic: %s
  Class: %s
  Data: %s
  Type: %s
  Machine: %s
  Version: %#x
  OS/ABI: %s
  ABI Version: %s
  Entry point address: %#x
  Start of program headers: %d
  Start of section headers: %d
  Size of program headers: %d
  Number of program headers: %d
  Size of section headers: %d
  Number of section headers: %d
  Section header string table index: %d
`,
             elf.header.identifier.data,
             elf.header.identifier.fileClass,
             elf.header.identifier.dataEncoding,
             elf.header.objectFileType,
             elf.header.machineISA,
             elf.header.version_,
             elf.header.identifier.osABI,
             elf.header.identifier.abiVersion,
             elf.header.entryPoint,
             elf.header.programHeaderOffset,
             elf.header.sectionHeaderOffset,
             elf.header.sizeOfProgramHeaderEntry,
             elf.header.numberOfProgramHeaderEntries,
             elf.header.sizeOfSectionHeaderEntry,
             elf.header.numberOfSectionHeaderEntries,
             elf.header.sectionHeaderStringTableIndex
        );
}

void printSectionHeaders(ELF elf)
{
    writeln(`Section Headers:
 [Nr] Name Type Address Offset Size EntSize Flags Link Info Align`);
    foreach (n, section; elf.sections.enumerate)
        writefln(" [%d] %s %s %#o %#o %#o %d %s %s %s",
                 n,
                 section.name,
                 section.type,
                 section.address,
                 section.offset,
                 section.entrySize,
                 section.flags,
                 section.link,
                 section.info,
                 section.addrAlign);
}

void printSymbols(ELF elf)
{
    foreach (section; only(".dynsym", ".symtab"))
    {
        auto s = elf.getSection(section);
        if (s.isNull) continue;  // skip if it hasn't.
        auto symbols = SymbolTable(s).symbols;
        writefln(`Symbol table '%s' contains %d entries:
  Num: Value Size Type Bind Vis Ndx Name`, section, symbols.walkLength);

        foreach (n, symbol; symbols.enumerate)
        {
            string name;
            if (symbol.name.length > 25)
                name = symbol.name[0 .. 25];
            else
                name = symbol.name;
            writefln(`  [%d] %s %d %s %s %s %s %s`,
                     n,
                     symbol.value,
                     symbol.size,
                     symbol.type,
                     symbol.binding,
                     symbol.info,
                     symbol.sectionIndex,
                     name
                );
        }
    }
}
