#!/system/bin/sh
# Best-effort runtime permission grants.
#
# Permissions introduced in newer Android releases (for example
# android.permission.ACCESS_LOCAL_NETWORK on API 37) do not exist on older
# builds; an unknown permission must not abort the whole driver stack.
set -u
MODDIR=$(CDPATH= cd -- "${0%/*}/.." && pwd)
. "$MODDIR/bin/common.sh"
init_state
ok=0
skip=0
for permission in android.permission.NEARBY_WIFI_DEVICES android.permission.ACCESS_LOCAL_NETWORK android.permission.BLUETOOTH_SCAN android.permission.BLUETOOTH_ADVERTISE android.permission.ACCESS_FINE_LOCATION android.permission.ACCESS_COARSE_LOCATION android.permission.ACCESS_BACKGROUND_LOCATION android.permission.ACCESS_MEDIA_LOCATION; do
    if out=$(framework pm grant --user 0 "$PKG" "$permission" 2>&1); then
        ok=$((ok+1))
    else
        skip=$((skip+1))
        case "$out" in
            *Unknown\ permission*) echo "skip $permission (not declared on this build)" >> "$STATE/permission-grants.log" ;;
            *) echo "skip $permission: $(printf '%s' "$out" | head -n 1)" >> "$STATE/permission-grants.log" ;;
        esac
    fi
done
echo "PERMISSIONS granted=$ok skipped=$skip" >> "$STATE/permission-grants.log"
exit 0
