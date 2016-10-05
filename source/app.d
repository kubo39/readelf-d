import elf;
import elf.low;

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
  -a --all               Equivalent to: -h -l -S -s
  -h --file-header       Display the ELF file header
  -l --program-headers   Display the program headers
  -S --section-headers   Display sections' headers
  -e --headers           Equivalent to: -h -l -S
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

    bool help, all, fileHeader, programHeaders, sectionHeaders, allHeaders, symbols;

    getopt(
        args,
        std.getopt.config.caseSensitive,
        "a|all", &all,
        "h|file-header", &fileHeader,
        "l|program-headers", &programHeaders,
        "S|section-headers", &sectionHeaders,
        "e|headers", &allHeaders,
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
    if (allHeaders)
    {
        fileHeader = true;
        sectionHeaders = true;
        programHeaders = true;
    }

    ELF elf = ELF.fromFile(args[1]);

    if (fileHeader)
        printELFHeader(elf.header);
    if (programHeaders)
        printProgramHeaders(elf);
    if (sectionHeaders)
        printSectionHeaders(elf);
    if (symbols)
        printSymbols(elf);
}


void printELFHeader(ELFHeader header)
{
    writefln(`ELF Header:
  Magic: %s
  Class: %s
  Data: %s
  Type: %s
  Machine: %s
  Version: %d
  OS/ABI: %s
  ABI Version: %s
  Entry point address: %#x
  Start of program headers: %d
  Start of section headers: %d
  Size of program headers: %d
  Number of program headers: %d
  Size of section headers: %d
  Number of section headers: %d
  Section header string table index: %d`,
             header.identifier.data,
             header.identifier.fileClass,
             header.identifier.dataEncoding,
             header.objectFileType,
             header.machineISA,
             header.version_,
             header.identifier.osABI,
             header.identifier.abiVersion,
             header.entryPoint,
             header.programHeaderOffset,
             header.sectionHeaderOffset,
             header.sizeOfProgramHeaderEntry,
             header.numberOfProgramHeaderEntries,
             header.sizeOfSectionHeaderEntry,
             header.numberOfSectionHeaderEntries,
             header.sectionHeaderStringTableIndex
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

    // 64bit.
    if (elf.header.identifier.fileClass == FileClass.class64)
    {
        ProgramHeader64[] phdrs = getProgramHeaders64(elf);
        foreach (phdr; phdrs)
        {
            writefln("  %s %08#x %08#x %08#x %08#x %08#x %s %d",
                     phdr.progtype,
                     phdr.offset,
                     phdr.vaddr,
                     phdr.paddr,
                     phdr.filesz,
                     phdr.memsz,
                     toString(phdr.flags),
                     phdr.align_
                );
        }
    }
    else // 32bit.
    {
        assert(false);
    }
}


// specialized for ProgramFlags.
string toString(ProgramFlags flags)
{
    import std.format : format;
    return format("%s%s%s",
                  flags & ProgramFlags.READABLE ? "R" : " ",
                  flags & ProgramFlags.WRITABLE ? "W" : " ",
                  flags & ProgramFlags.EXECUTABLE ? "E" : " ");
}


abstract class ProgramHeader
{
}


final class ProgramHeader32 : ProgramHeader
{
    ProgramType progtype;
    size_t offset;
    size_t vaddr;
    size_t paddr;
    size_t filesz;
    size_t memsz;
    ProgramFlags flags;
    size_t align_;
}


final class ProgramHeader64 : ProgramHeader
{
    ProgramType progtype;
    ProgramFlags flags;
    size_t offset;
    size_t vaddr;
    size_t paddr;
    size_t filesz;
    size_t memsz;
    size_t align_;
}


immutable sizeOfPogramHeader = 56;


enum ProgramType : uint
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


enum ProgramFlags : uint
{
    NONE = 0,
    EXECUTABLE = 1,
    WRITABLE = 2,
    READABLE = 3
}


ProgramHeader32[] getProgramHeaders32(ELF elf)
{
    import std.system;
    import std.bitmanip : read;

    auto phdrLen = elf.header.numberOfProgramHeaderEntries;
    ProgramHeader32[] phdrs;
    phdrs.reserve(phdrLen);

    // TODO: 32bit.
    assert(false, "Sorry, 32-bit arch is not supported yet.");
}


ProgramHeader64[] getProgramHeaders64(ELF elf)
{
    import std.system;
    import std.bitmanip : read;

    auto phdrLen = elf.header.numberOfProgramHeaderEntries;
    ProgramHeader64[] phdrs;
    phdrs.reserve(phdrLen);

    foreach (i; 0 .. phdrLen)
    {
        auto start = elf.header.programHeaderOffset + sizeOfPogramHeader * i;
        auto phdr = new ProgramHeader64;
        auto buffer = cast(ubyte[]) elf.m_file[start .. start + sizeOfPogramHeader].dup;

        // littleEndian.
        if (elf.header.identifier.dataEncoding == DataEncoding.littleEndian)
        {
            phdr.progtype = cast(ProgramType) buffer.read!(uint, Endian.littleEndian);
            phdr.flags = cast(ProgramFlags) buffer.read!(uint, Endian.littleEndian);
            phdr.offset = buffer.read!(ulong, Endian.littleEndian);
            phdr.vaddr = buffer.read!(ulong, Endian.littleEndian);
            phdr.paddr = buffer.read!(ulong, Endian.littleEndian);
            phdr.filesz = buffer.read!(ulong, Endian.littleEndian);
            phdr.memsz = buffer.read!(ulong, Endian.littleEndian);
            phdr.align_ = buffer.read!(ulong, Endian.littleEndian);
        }
        else  // bigEndian.
        {
            phdr.progtype = cast(ProgramType) buffer.read!(uint, Endian.bigEndian);
            phdr.flags = cast(ProgramFlags) buffer.read!(uint, Endian.bigEndian);
            phdr.offset = buffer.read!(ulong, Endian.bigEndian);
            phdr.vaddr = buffer.read!(ulong, Endian.bigEndian);
            phdr.paddr = buffer.read!(ulong, Endian.bigEndian);
            phdr.filesz = buffer.read!(ulong, Endian.bigEndian);
            phdr.memsz = buffer.read!(ulong, Endian.bigEndian);
            phdr.align_ = buffer.read!(ulong, Endian.bigEndian);
        }
        assert(buffer.length == 0);
        phdrs ~= phdr;
    }
    return phdrs;
}


void printSectionHeaders(ELF elf)
{
    writeln(`
Section Headers:
 [Nr] Name Type Address Offset Size EntSize Flags Link Info Align`);
    foreach (n, section; elf.sections.enumerate)
        writefln(" [%d] %s %s %08#x %08#x %08#x %s %s %s %s",
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
        writefln(`
Symbol table '%s' contains %d entries:
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
