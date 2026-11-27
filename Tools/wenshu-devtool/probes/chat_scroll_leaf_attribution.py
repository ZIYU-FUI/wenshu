#!/usr/bin/env python3
"""chat_scroll_leaf_attribution.py -- attribute a time-profile sample to the OWNER of its LEAF frame.

WHY THIS EXISTS
  A frame-accumulating roll-up gives every frame in a stack the sample's
  weight, so a subsystem's "share" becomes a function of stack depth instead
  of cost.  This script attributes each sample to the LEAF frame (= where the
  CPU actually was) and reports the sample COUNT per owner.

  THREE FACTS AN xctrace TIME-PROFILE EXPORT HIDES, ALL HANDLED HERE
  1. THE LEAF IS THE FIRST FRAME of a row's backtrace.  The frames run
     leaf-first and the thread's entry point (start_wqthread) is LAST.
  2. EVERY NAME ARRIVES BY REFERENCE.  A row carries `<frame ref="1176"/>`;
     the name lives in one earlier `<frame id="1176" name="...">`.  A binary
     can be referenced too (`<binary ref="51"/>`).  Without resolving the
     references, most leaves look unnamed.
  3. THE BINARY IS THE FRAME'S CHILD element.  A referenced frame therefore
     keeps ITS OWN binary, taken from its declaration, not from the row that
     references it.

  THE ATTRIBUTION IS OBJECTIVE: the owner is the BINARY that declares the
  leaf frame, so the reader does not have to trust a name pattern.  The
  name-based buckets are a second, finer view of the same samples.

  The buckets are TOTAL: every Main Thread row lands in exactly one bucket,
  so the counts add up to the row count and a reader can check that.

Usage:
  chat_scroll_leaf_attribution.py <time-profile.xml> [label] [the-app-binary-name]

IT PRINTS THE TREE'S HEAD at run time, so a re-run against a later commit
  names that commit.  The numbers describe the BUILD the trace recorded, not
  the tree the reader stands on: the input is an export taken on 2026-11-27
  against a working tree whose gate flag was compiled into two throwaway
  bundles, so re-measuring the same export on a later commit returns the same
  table, and a NEW recording needs the driver in
  `docs/agents/2026-11-27-session-close-chat-scroll-jank.md`.
"""
import re
import sys
import collections

ROW = re.compile(r'<row>(.*?)</row>', re.S)
THREAD = re.compile(r'<thread\b([^>]*?)(?:/>|>)')
THREAD_ID = re.compile(r'\bid="(\d+)"')
THREAD_REF = re.compile(r'\bref="(\d+)"')
THREAD_FMT = re.compile(r'\bfmt="([^"]*)"')
# A frame element either closes itself (`<frame ref="1176"/>`) or wraps a
# <binary> child (`<frame id="60" name="..."><binary ref="51"/></frame>`).
FRAME = re.compile(r'<frame\b([^>]*?)(?:/>|>(.*?)</frame>)', re.S)
FRAME_ID = re.compile(r'\bid="(\d+)"')
FRAME_REF = re.compile(r'\bref="(\d+)"')
FRAME_NAME = re.compile(r'\bname="([^"]*)"')
BINARY = re.compile(r'<binary\b([^>]*?)(?:/>|>)')
BINARY_ID = re.compile(r'\bid="(\d+)"')
BINARY_REF = re.compile(r'\bref="(\d+)"')
BINARY_NAME = re.compile(r'\bname="([^"]*)"')

# The owner of a leaf frame, by the BINARY that declares it.  This is the
# objective attribution: a name pattern can be argued with, a binary cannot.
OWNERS = [
    ("THE APP'S OWN BINARY", None),          # = the app itself, matched by name
    ("SwiftUI's own machinery",
     re.compile(r'^(SwiftUI|SwiftUICore|AttributeGraph|UIFoundation)$')),
    ('the Swift / ObjC runtime',
     re.compile(r'^(libswiftCore|libswift_|libobjc|libsystem_|dyld|libdyld)')),
    ('Foundation / CoreFoundation',
     re.compile(r'^(Foundation|CoreFoundation|CollectionsInternal)')),
    ('the text engine', re.compile(r'^(CoreText|libFontParser)')),
    ('AppKit / the hosting bridge',
     re.compile(r'^(AppKit|CoreUI|HIToolbox|CoreAutoLayout|SkyLight)')),
    ('the graphics stack',
     re.compile(r'^(CoreGraphics|CoreAnimation|QuartzCore|vImage|CoreSVG|'
                r'ColorSync|libhvf|CoreServicesInternal|SFSymbols)$')),
    ('the render server', re.compile(r'^(RenderBox)$')),
    ('the system libraries', re.compile(r'^(libicucore|libmecab|libvDSP|'
                                        r'libc\+\+|libc\+\+abi|CoreNLP|'
                                        r'CarbonCore|ConfigurationProfiles|'
                                        r'libswiftos|libswiftObjectiveC|'
                                        r'libswiftUniformTypeIdentifiers|'
                                        r'Combine|libcache)')),
]

# The class the session record's material section measures.  It is named ONCE,
# so the leaf bucket in the table below and the two-way arm further down
# cannot drift apart: the arm reports the same class the bucket counts.
MATERIAL = re.compile(
    r'NSVisualEffect|VisualEffect|CAGlass|GlassEffect|NSBackingStore|'
    r'CALayer|CAGradient|CAFilter|NSGraphics|_AnyResolvedPaint|'
    r'CA::Layer|CATransaction', re.I)

# The finer, name-based view of the same samples.
NAMES = [
    ('SwiftUI\'s attribute graph', re.compile(
        r'AG::|AGGraph|Attribute\.init|Attribute::|PropertiesTransform|'
        r'EnvironmentBox|Graph::|AttributeGraph|propagate_dirty|'
        r'Subgraph::|LayoutDescriptor|AGGraphGet|AGGraphSet', re.I)),
    ('material / glass / the backing store', MATERIAL),
    ('the text engine (CoreText)', re.compile(
        r'CoreText|CTFont|CTFramesetter|CTTypesetter|CTRun|CTLine|'
        r'CoreFoundation|NSCoreTypesetter|TGlyphEncoder|TFontCascade|'
        r'TUnicodeEncoder|CTEmoji|NSStringDrawing', re.I)),
    ('the Swift / ObjC runtime', re.compile(
        r'^(swift[:_]|objc[:_]|_objc|_swift|swift_task|swift_retain|'
        r'swift_release|swift_alloc|swift_dealloc|swift_slow|swift_cvw|'
        r'swift_beginAccess|swift_conforms|swift_array|swift_get|'
        r'__CF_|_xzm_|_platform_mem|_CF|MAGIC|Malloc|___chkstk|_dyld_|'
        r'weak_entry|util::UntypedTable)', re.I)),
    ('the AppKit bridge', re.compile(
        r'NSHostingView|NSApplication|NSWindow|NSView|AppKit|'
        r'_NSAccessibility|NSResponder|NSImage|NSFont|NSString|NSMenu|'
        r'NSTextField|NSButton|CoreUI', re.I)),
    ('CoreAnimation / the render server', re.compile(
        r'CoreAnimation|CA::Transaction|CADisplayLink|CA::Render|'
        r'CATransaction', re.I)),
    ("the app's own code", re.compile(
        r'^(Chat|Wenshu|Inspector|Editor|Sidebar|Transcript|Band|Composer)')),
]

# A leaf that is a bare address, or the exporter's own placeholder, carries
# no symbol: it is counted as UNSYMBOLISED, never dropped.
UNSYMBOLISED = re.compile(r'^(0x[0-9a-fA-F]+|<deduplicated_symbol>|'
                          r'&lt;deduplicated_symbol&gt;)$')


def binary_name(attrs, inner, binaries):
    """The binary a frame element names, resolving the ref indirection.

    The child is either `<binary name="X"/>` (rare) or `<binary ref="N"/>`
    pointing at one of the handful of `<binary id="N" name="X">` declarations.
    """
    match = BINARY.search(inner or '')
    if not match:
        return None
    name = BINARY_NAME.search(match.group(1))
    if name:
        return name.group(1)
    ref = BINARY_REF.search(match.group(1))
    return binaries.get(ref.group(1)) if ref else None


def build_maps(data):
    """The id -> name maps the export declares, for threads, frames, binaries.

    A frame's map holds (name, binary name), because the binary is the frame
    element's child and a referenced frame keeps its own binary.
    """
    threads, frames, binaries = {}, {}, {}
    for match in THREAD.finditer(data):
        attrs = match.group(1)
        idm = THREAD_ID.search(attrs)
        fmtm = THREAD_FMT.search(attrs)
        if idm and fmtm:
            threads[idm.group(1)] = fmtm.group(1)
    for match in BINARY.finditer(data):
        attrs = match.group(1)
        idm = BINARY_ID.search(attrs)
        namem = BINARY_NAME.search(attrs)
        if idm and namem:
            binaries[idm.group(1)] = namem.group(1)
    for match in FRAME.finditer(data):
        attrs = match.group(1)
        idm = FRAME_ID.search(attrs)
        namem = FRAME_NAME.search(attrs)
        if not (idm and namem):
            continue
        binary = None
        inner = match.group(2)
        if inner:
            bmatch = BINARY.search(inner)
            if bmatch:
                bname = BINARY_NAME.search(bmatch.group(1))
                if bname:
                    binary = bname.group(1)
                else:
                    bref = BINARY_REF.search(bmatch.group(1))
                    if bref:
                        binary = binaries.get(bref.group(1))
        frames[idm.group(1)] = (namem.group(1), binary)
    return threads, frames, binaries


def owner_of(binary, app_binary):
    """The owner group of a leaf frame, by the binary that declares it."""
    if not binary:
        return 'no binary names the leaf'
    if app_binary and binary == app_binary:
        return "THE APP'S OWN BINARY"
    for name, pattern in OWNERS:
        if pattern is None:
            continue
        if pattern.match(binary):
            return name
    return f'another binary ({binary})'


def main():
    path = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else path
    app_binary = sys.argv[3] if len(sys.argv) > 3 else None

    with open(path, 'r', encoding='utf-8', errors='replace') as handle:
        data = handle.read()

    threads, frames, binary_map = build_maps(data)
    total_rows = 0
    main_rows = 0
    owners = collections.Counter()
    names = collections.Counter()
    app_leaf = 0
    app_in_stack = 0
    leaf_names = collections.Counter()
    material_mentioned = 0
    material_leaf = 0
    material_symbols = collections.Counter()

    for match in ROW.finditer(data):
        total_rows += 1
        row = match.group(1)
        tmatch = THREAD.search(row)
        thread = None
        if tmatch:
            attrs = tmatch.group(1)
            idm = THREAD_ID.search(attrs)
            if idm:
                fmtm = THREAD_FMT.search(attrs)
                thread = fmtm.group(1) if fmtm else threads.get(idm.group(1))
            else:
                refm = THREAD_REF.search(attrs)
                thread = threads.get(refm.group(1)) if refm else None
        if not thread or not thread.startswith('Main Thread'):
            continue
        main_rows += 1

        # Every frame of this row, leaf-first.  An inline frame names itself
        # and points at its binary by ref; a `<frame ref="N"/>` inherits both
        # from the declaration, which is where its OWN binary lives.
        row_frames = []
        for fmatch in FRAME.finditer(row):
            attrs = fmatch.group(1)
            inner = fmatch.group(2)
            namem = FRAME_NAME.search(attrs)
            if namem:
                name = namem.group(1)
                binary = binary_name(attrs, inner, binary_map)
            else:
                refm = FRAME_REF.search(attrs)
                if refm:
                    name, binary = frames.get(refm.group(1), (None, None))
                else:
                    name, binary = None, None
            row_frames.append((name, binary))

        if not row_frames:
            owners['no frames at all'] += 1
            names['no frames at all'] += 1
            continue

        leaf_name, leaf_binary = row_frames[0]
        owners[owner_of(leaf_binary, app_binary)] += 1
        if leaf_binary and app_binary and leaf_binary == app_binary:
            app_leaf += 1
        if any(binary == app_binary for _, binary in row_frames):
            app_in_stack += 1
        if leaf_name:
            leaf_names[leaf_name] += 1

        # The material class, measured two ways on the SAME rows: a frame of
        # the class ANYWHERE in the stack (what a roll-up charges it) against
        # the class IS the leaf (where the CPU actually was).  The pair is
        # printed together, because the gap between them is the whole point.
        if any(MATERIAL.search(name or '') for name, _ in row_frames):
            material_mentioned += 1
        if leaf_name and MATERIAL.search(leaf_name):
            material_leaf += 1
            material_symbols[leaf_name] += 1

        if not leaf_name or UNSYMBOLISED.match(leaf_name):
            names['no symbol at the leaf'] += 1
            continue
        for name, pattern in NAMES:
            if pattern.search(leaf_name):
                names[name] += 1
                break
        else:
            names['some other framework'] += 1

    print(f"== {label} ==")
    print(f"the path: {path}")
    print(f"rows in the table: {total_rows}")
    print(f"Main Thread rows: {main_rows}")
    print("--- the OWNER of the leaf frame (by the binary that declares it) ---")
    total = 0
    for name, count in owners.most_common():
        total += count
        share = (count / main_rows * 100) if main_rows else 0.0
        print(f"  {count:6d}  {share:5.1f}%  {name}")
    share = (total / main_rows * 100) if main_rows else 0.0
    print(f"  {total:6d}  {share:5.1f}%  THE TOTAL (= the Main Thread row count)")
    print("--- the leaf frame's NAME, in the same buckets ---")
    total = 0
    for name, count in names.most_common():
        total += count
        share = (count / main_rows * 100) if main_rows else 0.0
        print(f"  {count:6d}  {share:5.1f}%  {name}")
    share = (total / main_rows * 100) if main_rows else 0.0
    print(f"  {total:6d}  {share:5.1f}%  THE TOTAL (= the Main Thread row count)")
    if app_binary:
        print(f"--- the app's own binary ({app_binary}) ---")
        print(f"  its frames are the LEAF in {app_leaf} of {main_rows} rows "
              f"({app_leaf / main_rows * 100:.1f}%)")
        print(f"  its frames appear ANYWHERE in {app_in_stack} of {main_rows} "
              f"rows ({app_in_stack / main_rows * 100:.1f}%)")
    print("--- the material class, measured two ways ---")
    print(f"  mentioned ANYWHERE in the stack in {material_mentioned} of "
          f"{main_rows} rows ({material_mentioned / main_rows * 100:.1f}%)")
    print(f"  the class IS the LEAF in {material_leaf} of {main_rows} rows "
          f"({material_leaf / main_rows * 100:.1f}%)")
    print("  its leaf symbols, the largest first:")
    for name, count in material_symbols.most_common(5):
        print(f"    {count:6d}  {name[:100]}")
    print("--- the top 15 leaf names ---")
    for name, count in leaf_names.most_common(15):
        print(f"    {count:6d}  {name[:100]}")


if __name__ == '__main__':
    main()
