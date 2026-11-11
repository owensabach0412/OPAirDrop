#!/system/bin/sh
# Validate the active Mosey base APK (and its ABI split) against the selected
# original/patched manifest.
#
# Locale/density splits differ between ROM builds of the same Mosey version
# (realme's build ships 13 splits where the OnePlus package has 6), and the
# density split is not byte-identical even when base.apk is. Pinning the whole
# split set rejects a perfectly valid install, so only the two splits that
# carry code and native libraries are verified here.
set -eu
MODDIR=$(CDPATH= cd -- "${0%/*}/.." && pwd)
. "$MODDIR/bin/common.sh"
case "${1:-runtime}" in
    original) manifest="$MODDIR/APP-SHA256SUMS";;
    patched) manifest="$MODDIR/APP-CALLBACK-SHA256SUMS";;
    runtime)
        if [ -e "$STATE/callback-off" ]; then manifest="$MODDIR/APP-SHA256SUMS"
        else manifest="$MODDIR/APP-CALLBACK-SHA256SUMS"; fi;;
    *) exit 2;;
esac

expected() { awk -v n="$1" '$2==n {print $1; exit}' "$manifest"; }
base_want=$(expected base.apk)
arm_want=$(expected split_config.arm64_v8a.apk)
[ -n "$base_want" ] || { echo 'Manifest has no base.apk entry'; exit 3; }

paths=$(framework pm path --user 0 "$PKG" | sed -n 's/^package://p')
[ -n "$paths" ] || { echo 'Mosey is not installed for user0'; exit 3; }

pick() { printf '%s\n' "$paths" | awk -v n="$1" -F/ '$NF==n {print; exit}'; }
base=$(pick base.apk)
[ -n "$base" ] || { echo 'Active base.apk missing'; exit 3; }
[ "$(sha256sum "$base" | awk '{print $1}')" = "$base_want" ] || {
    echo "Active base APK differs (${1:-runtime})"; exit 3;
}

if [ -n "$arm_want" ]; then
    arm=$(pick split_config.arm64_v8a.apk)
    [ -n "$arm" ] || { echo 'Active arm64 split missing'; exit 3; }
    [ "$(sha256sum "$arm" | awk '{print $1}')" = "$arm_want" ] || {
        echo "Active arm64 split differs (${1:-runtime})"; exit 3;
    }
fi

echo "MOSEY_60715_BASE_VERIFIED ${1:-runtime} splits=$(printf '%s\n' "$paths" | wc -l | tr -d ' ')"
