import core.stdc.stdlib;
import std.getopt;
import std.range;
import std.stdio;

import elf;
import elf.low;

enum USAGE = `readelf-d [OPTION] elf-file(s)
 Display information about the contents of ELF format files
 Options are:`;

int main(string[] args)
{
    bool help, all, fileHeader, programHeaders, sectionHeaders, dynsyms, notes, allHeaders, symbols;
    string debugDump;

    auto helpInformation = args.getopt(
        std.getopt.config.caseSensitive,
        "a|all", "Equivalent to: -h -l -S -n -s", &all,
        "h|file-header", "Display the ELF file header", &fileHeader,
        "l|program-headers", "Display the program headers", &programHeaders,
        "S|section-headers", "Display sections' headers", &sectionHeaders,
        "dyn-syms", "Display the dynamic symbol table", &dynsyms,
        "n|notes", "Display core notes", &notes,
        "e|headers", "Equivalent to: -h -l -S", &allHeaders,
        "s|symbols", "Display the symbol table", &symbols,
        "debug-dump", "Display the contents of DWARF2 debug sections", &debugDump,
        "H|help", "Display this information", &help
        );

    scope(failure)
    {
        defaultGetoptPrinter(USAGE, helpInformation.options);
        return EXIT_FAILURE;
    }

    if (help)
    {
        defaultGetoptPrinter(USAGE, helpInformation.options);
        return EXIT_SUCCESS;
    }
    else if (args.length < 2)
    {
        defaultGetoptPrinter(USAGE, helpInformation.options);
        return EXIT_FAILURE;
    }

    if (all)
    {
        fileHeader = true;
        sectionHeaders = true;
        programHeaders = true;
        symbols = true;
        notes = true;
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
    if (dynsyms)
        printDynSyms(elf);
    if (notes)
        printNotes(elf);
    if (symbols)
        printSymbols(elf);
    if (debugDump.length)
        if (debugDump == "abbrev")
            printDebugAbbrev(elf);

    return EXIT_SUCCESS;
}

string magicString(ELFIdent ident)
{
    import std.format : format;
    string magic;
    string formatTemplate = "%x %x %x %x %x %x %x %x %x %(%s %) %x";
    with (ident)
    {
        magic = formatTemplate.format(mag0, mag1, mag2, mag3,
                                      class_, data, version_,
                                      osabi, abiversion,
                                      pad, nident);
    }
    return magic;
}

void printELFHeader(ELFHeader header)
{
    auto magicString = magicString(header.identifier.data);
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
             magicString,
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
  Type  Offset  VirtAddr  PhysAddr  FileSiz  MemSiz  Flags  Align`,
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
            writefln("  %s  %08#x  %08#x  %08#x  %08#x  %08#x  %s  %d",
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
        assert(false, "Sorry, 32-bit arch is not supported.");
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


ProgramHeader64[] getProgramHeaders64(ELF elf)
{
    import std.bitmanip : read;
    import std.system : Endian;

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
            writefln(`  %d: %08#x %d %s %s %s %s %s`,
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


void printDynSyms(ELF elf)
{
    auto section = elf.getSection(".dynsym");
    if (section.isNull) return;
    auto symbols = SymbolTable(section).symbols;
    writeln(`
Symbol table '.dynsym' contains %d entries:
   Num: Value Size Type Bind Vis Ndx Name
`, symbols.walkLength);

    foreach (n, symbol; symbols.enumerate)
    {
        string name;
        if (symbol.name.length > 25)
            name = symbol.name[0 .. 25];
        else
            name = symbol.name;
        writefln(`  %d: %08#x %d %s %s %s %s %s`,
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


void printNotes(ELF elf)
{
    foreach (section; elf.sections)
        if (section.type == SectionType.note)
            writefln("Display notes found in: %s", section.name);
}


void printDebugAbbrev(ELF elf)
{
    ELFSection section = elf.getSection(".debug_abbrev");
    auto da = DebugAbbrev(section);

    writeln(`
Contents of the .debug_abbrev section:
`);
    foreach (i, tag; da.tags)
    {
        writefln("  Number TAG (0x%x)", tag.code);
        writefln("   %d DW_TAG_%s [%s]", i, tag.name,
                 tag.hasChildren ? "has children" : "no children");
        foreach (attr; tag.attributes)
            writefln("    DW_AT_%s\tDW_FORM_%s", attr.name, attr.form);
    }
}
