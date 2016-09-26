import elf;

import std.getopt;
import std.stdio;

void main(string[] args)
{
    bool help, fileHeader, programHeaders, sectionHeaders;
    string filename;

    getopt(
        args,
        "h|file-header", &fileHeader,
        "l|program-headers", &programHeaders,
        "S|section-headers", &sectionHeaders,
        "f|file-name", &filename
        );

    auto elf = ELF.fromFile(filename);
    if (fileHeader)
        printELFHeader(elf);
    if (sectionHeaders)
        printSectionHeaders(elf);
}

void printELFHeader(ELF elf)
{
    writefln(`
ELF Header:
  Magic: %s
  Type: %s
  Machine: %s
  Version: %s
  Entry point address: %#x
  Start of program headers: %d
  Start of section headers: %d
  Size of program headers: %d
  Number of program headers: %d
  Size of section headers: %d
  Number of section headers: %d
  Section header string table index: %d
`,
             elf.header.identifier,
             elf.header.objectFileType,
             elf.header.machineISA,
             elf.header.version_,
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
    writeln("Name Type Address Offset Size EntSize Flags Link Info Align");
    foreach (section; elf.sections)
        writefln("%s %s %#o %#o %#o %d %s %s %s",
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
