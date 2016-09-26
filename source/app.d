import elf;

import std.getopt;
import std.range;
import std.stdio;

void main(string[] args)
{
    bool help, all, fileHeader, sectionHeaders;
    string filename;

    try
    {
        getopt(
            args,
            "a|all", &all,
            "h|file-header", &fileHeader,
            "S|section-headers", &sectionHeaders,
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
  -a --all               Equivalent to: -h -S
  -h --file-header       Display the ELF file header
  -S --section-headers   Display the sections' header
  -f --file-name         ELF file to inspect
  -H --help              Display this information
`);
        return;
    }

    auto elf = ELF.fromFile(filename);
    if (all || fileHeader)
        printELFHeader(elf);
    if (all || sectionHeaders)
        printSectionHeaders(elf);
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
