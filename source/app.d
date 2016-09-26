import elf;

import std.getopt;
import std.range;
import std.stdio;

void main(string[] args)
{
    bool help, all, fileHeader, sectionHeaders, symbols;
    string filename;

    try
    {
        getopt(
            args,
            std.getopt.config.caseSensitive,
            "a|all", &all,
            "h|file-header", &fileHeader,
            "S|section-headers", &sectionHeaders,
            "s|symbols", &symbols,
            std.getopt.config.required,
            "f|file-name", &filename,
            "H|help", &help
            );
    }
    catch (GetOptException)
    {
        help = true;
    }

    if (help)
    {
        writeln(`readelf-d
USAGE:
 readelf-d [OPTION] [ARG]..
 Display information about the contents of ELF format files
 Options are:
  -a --all               Equivalent to: -h -S -s
  -h --file-header       Display the ELF file header
  -S --section-headers   Display sections' headers
  -s --symbols           Display the symbol table
  -f --file-name         ELF file to inspect
  -H --help              Display this information
`);
        return;
    }

    if (all)
    {
        fileHeader = true;
        sectionHeaders = true;
        symbols = true;
    }

    auto elf = ELF.fromFile(filename);
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
    foreach (section; only(".symtab", ".dynsym"))
    {
        auto s = elf.getSection(section);
        auto symbolTable = SymbolTable(s);
        writefln(`Symbol table '%s':
  Num: Value Size Type Bind Vis Ndx Name`, section);

        foreach (n, symbol; symbolTable.symbols.enumerate)
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
