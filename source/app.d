import elf;
import elf.low;

import std.getopt;
import std.range;
import std.stdio;
import core.stdc.stdlib : exit;
import std.system;
import std.bitmanip;


void usage()
{
    writeln(`readelf-d
USAGE:
 readelf-d [OPTION] elf-file..
 Display information about the contents of ELF format files
 Options are:
  -a --all               Equivalent to: -h -S -s
  -h --file-header       Display the ELF file header
  -l --program-headers   Display the program headers
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

    bool help, all, fileHeader, programHeaders, sectionHeaders, symbols;

    getopt(
        args,
        std.getopt.config.caseSensitive,
        "a|all", &all,
        "h|file-header", &fileHeader,
        "l|program-headers", &programHeaders,
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
        programHeaders = true;
        symbols = true;
    }

    ELF elf = ELF.fromFile(args[1]);

    if (fileHeader)
        printELFHeader(elf);
    if (programHeaders)
        printProgramHeaders(elf);
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

void printProgramHeaders(ELF elf)
{
    writefln(`
Elf file type is %s
Entry point %#x
There are %d program headers, starting at offset %d

Program Headers:
  Type Offset VirtAddr PhysAddr FileSiz MemSiz Flags Align`,
             elf.header.objectFileType,
             elf.header.entryPoint,
             elf.header.numberOfProgramHeaderEntries,
             elf.header.programHeaderOffset
        );
    auto phdrs = getProgramHeaders(elf);
    foreach (phdr; phdrs)
    {
        writefln("  %s %#x %#x %#x %#x %#x %d %d",
                 phdr.progtype,
                 phdr.offset,
                 phdr.vaddr,
                 phdr.paddr,
                 phdr.filesz,
                 phdr.memsz,
                 phdr.flags,
                 phdr.align_
            );
    }
}

abstract class Phdr
{
    ProgType progtype;
    uint flags;
    size_t offset;
    size_t vaddr;
    size_t paddr;
    size_t filesz;
    size_t memsz;
    size_t align_;
}

final class Phdr64 : Phdr
{
}

enum ProgType
{
    NULL = 0,
    LOAD = 1,
    DYNAMIC = 2,
    INTERP = 3,
    NOTE = 4,
    SHLIB = 5,
    PHDR = 6,
    TLS = 7,
    GNU_EH_FRAME = 0x6474e550,
    GNU_STACK = 0x6474e551,
    GNU_RELRO = 0x6474e552
}


Phdr[] getProgramHeaders(ELF elf)
{
    auto phdrLen = elf.header.numberOfProgramHeaderEntries;
    Phdr[] phdrs;
    phdrs.reserve(phdrLen);

    // 64bit.
    if (elf.header.identifier.fileClass == FileClass.class64)
    {
        // littleEndian.
        if (elf.header.identifier.dataEncoding == DataEncoding.littleEndian)
        {
            foreach (i; 0 .. phdrLen)
            {
                auto start = elf.header.programHeaderOffset + 56 * i;
                auto phdr = new Phdr64;

                auto buffer = cast(ubyte[]) elf.m_file[start .. start + 56].dup;
                phdr.progtype = cast(ProgType) buffer.read!(uint, Endian.littleEndian);
                phdr.flags = buffer.read!(uint, Endian.littleEndian);
                phdr.offset = buffer.read!(ulong, Endian.littleEndian);
                phdr.vaddr = buffer.read!(ulong, Endian.littleEndian);
                phdr.paddr = buffer.read!(ulong, Endian.littleEndian);
                phdr.filesz = buffer.read!(ulong, Endian.littleEndian);
                phdr.memsz = buffer.read!(ulong, Endian.littleEndian);
                phdr.align_ = buffer.read!(ulong, Endian.littleEndian);
                phdrs ~= phdr;
            }
            return phdrs;
        }
        // TODO: bigEndian.
        else
        {
            assert(false);
        }
    }
    // TODO: 32bit.
    assert(false, "Sorry, 32-bit arch is not supported yet.");
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
