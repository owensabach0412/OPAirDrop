"""Build a de-gated test package for RMX5010 from the upstream v1.0.31 release.

Changes (minimal, auditable):
  1. customize.sh: drop model / SDK / kernel / KernelSU / metamodule gates.
  2. bin/control.sh: preflight -> root only; drop stock module size whitelist;
     relax STOCK_NOTE_* comparisons to "module has a build id".
  3. recompute SHA256SUMS (verify.sh checks it at install).
Nothing else is touched: payload, APKs, webroot and permissions stay upstream.
"""
import hashlib
import shutil
import zipfile
from pathlib import Path

SRC = Path('OPAirDrop-v1.0.31.zip')
WORK = Path('build_rmx')
OUT = Path('OPAirDrop-v1.0.31-RMX5010-test.zip')

if WORK.exists():
    shutil.rmtree(WORK)
WORK.mkdir()
with zipfile.ZipFile(SRC) as z:
    z.extractall(WORK)


def patch(rel, pairs):
    p = WORK / rel
    text = p.read_text(encoding='utf-8')
    for old, new in pairs:
        assert old in text, f'{rel}: pattern not found:\n{old[:120]}'
        text = text.replace(old, new)
    p.write_text(text, encoding='utf-8', newline='\n')
    print(f'patched {rel} ({len(pairs)} edits)')


patch('customize.sh', [(
    """[ "$(getprop ro.product.model)" = PJZ110 ] || abort 'Only PJZ110 is supported'
[ "$(getprop ro.build.version.sdk)" = 37 ] || abort 'SDK37 required'
[ "$(uname -r)" = '6.6.118-android15-8-g9bc34d5b0c79-abogki537459655-4k' ] || abort 'Kernel changed; ABI revalidation required'
[ "${KSU:-false}" = true ] || [ -x /data/adb/ksud ] || abort 'KernelSU required'
[ -e /data/adb/metamodule ] || abort 'KernelSU metamodule required'
""",
    """# RMX5010 port: device/kernel gates removed after manual verification
# (realme / sun / 6.6.89-android15-8-...-4k, provider+qca+mac80211+wonder verified).
""")])

patch('bin/control.sh', [
    ("""[ "$(id -u)" = 0 ] && [ "$(getprop ro.product.model)" = PJZ110 ] || return 2
    [ "$(getprop ro.build.version.sdk)" = 37 ] || return 2
    [ "$(uname -r)" = '6.6.118-android15-8-g9bc34d5b0c79-abogki537459655-4k' ] || return 2""",
     """[ "$(id -u)" = 0 ] || return 2"""),
    ("""        grep -q '^qca_cld3_peach_v2 12365824 ' /proc/modules || exit 3
        grep -q '^mac80211 1093632 0 ' /proc/modules || exit 3
""", ""),
    ("""[ "$note" = "$NOTE_qca_cld3_peach_v2" ] || [ "$note" = "$STOCK_NOTE_qca_cld3_peach_v2" ] || return 3""",
     """[ -n "$note" ] || return 3"""),
    ("""[ "$note" = "$NOTE_mac80211" ] || [ "$note" = "$STOCK_NOTE_mac80211" ] || return 3""",
     """[ -n "$note" ] || return 3"""),
    ("""        [ "$(module_note qca_cld3_peach_v2)" = "$STOCK_NOTE_qca_cld3_peach_v2" ] || return 13""",
     """        [ -n "$(module_note qca_cld3_peach_v2)" ] || return 13"""),
    ("""        [ "$(module_note mac80211)" = "$STOCK_NOTE_mac80211" ] || return 15""",
     """        [ -n "$(module_note mac80211)" ] || return 15"""),
    ("""        [ "$(module_note qca_cld3_peach_v2)" = "$STOCK_NOTE_qca_cld3_peach_v2" ] || exit 3
        [ "$(module_note mac80211)" = "$STOCK_NOTE_mac80211" ] || exit 3""",
     """        [ -n "$(module_note qca_cld3_peach_v2)" ] || exit 3
        [ -n "$(module_note mac80211)" ] || exit 3"""),
])

# recompute SHA256SUMS over every file except itself (format: "<sha256>  <relpath>")
lines = []
for p in sorted(WORK.rglob('*')):
    if p.is_file() and p.name != 'SHA256SUMS':
        rel = p.relative_to(WORK).as_posix()
        lines.append(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {rel}')
(WORK / 'SHA256SUMS').write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
print(f'SHA256SUMS: {len(lines)} entries')

if OUT.exists():
    OUT.unlink()
with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(WORK.rglob('*')):
        if p.is_file():
            z.write(p, p.relative_to(WORK).as_posix())
print(f'built {OUT} ({OUT.stat().st_size} bytes)')
