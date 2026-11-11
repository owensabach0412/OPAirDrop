#!/system/bin/sh
# Authenticate the signed APK before exposing the callback-patched APK.
#
# Two evidence levels are accepted:
#   module  - GMS lists com.google.android.mosey in the chimera module table
#             (OnePlus builds). The original flow brings the provider up first
#             so GMS loads the signed APK, then installs the patched view.
#   nearby  - the ROM runs Quick Share through GMS NearbySharingService
#             (realme builds) and no Mosey module row is published. Forcing the
#             provider from the background is refused by the platform here, so
#             only the active base APK is patched; GMS starts Mosey when the
#             user opens Quick Share.
set -eu
MODDIR=$(CDPATH= cd -- "${0%/*}/.." && pwd)
. "$MODDIR/bin/common.sh"
AUTH="$STATE/callback-auth"
startup_trace AUTH_BEGIN
mkdir -p "$AUTH"
if [ -e "$STATE/callback-off" ]; then
    /system/bin/sh "$MODDIR/bin/app-check.sh" original
    exit 0
fi

dump=$(framework timeout 10 dumpsys activity service com.google.android.gms/.chimera.PersistentApiServiceNoInstantApps) || dump=
evidence=none
if printf '%s\n' "$dump" | grep -Eq '[|] com\.google\.android\.mosey [|] Version:'; then
    evidence=module
elif printf '%s\n' "$dump" | grep -q 'com\.google\.android\.gms\.nearby\.sharing\.NearbySharingService' &&
     printf '%s\n' "$dump" | grep -q 'Version: qs_v1'; then
    evidence=nearby
fi

gms_pid=$(pidof com.google.android.gms || true)
if same_boot "$AUTH/boot" && [ -n "$gms_pid" ] &&
   [ "$(cat "$AUTH/gms-pid" 2>/dev/null || true)" = "$gms_pid" ]; then
    /system/bin/sh "$MODDIR/bin/callback.sh" ensure
    exit 0
fi

/system/bin/sh "$MODDIR/bin/transfer-idle.sh"

if [ "$evidence" = module ]; then
    # Original flow: stop the old provider/radio, bring the module up so GMS
    # loads the signed APK, verify registration, then patch.
    /system/bin/sh "$MODDIR/bin/callback.sh" off
    /system/bin/sh "$MODDIR/bin/provider.sh" ensure || true
    n=0;registered=0
    while [ "$n" -lt 20 ]; do
        dump=$(framework timeout 6 dumpsys activity service com.google.android.gms/.chimera.PersistentApiServiceNoInstantApps) || dump=
        if printf '%s\n' "$dump" | grep -Eq '[|] com\.google\.android\.mosey [|] Version:'; then
            registered=1;break
        fi
        sleep 1;n=$((n+1))
    done
    [ "$registered" != 1 ] || startup_trace AUTH_REGISTERED
    /system/bin/sh "$MODDIR/bin/provider.sh" release || true
    reply=$(framework timeout 15 service call "$SERVICE" 2 i32 1 i32 4) || reply=
    printf '%s\n' "$reply" > "$AUTH/native-stop.txt"
    if [ "$registered" != 1 ]; then
        echo 'CALLBACK_AUTH_NOT_READY: original signed APK retained'
        exit 6
    fi
else
    # realme flow: do not fight the platform's background-start policy.
    if [ "$evidence" = nearby ]; then
        startup_trace AUTH_NEARBY
    else
        echo 'CALLBACK_AUTH_NO_GMS_EVIDENCE: patching the installed base only'
    fi
    framework pm disable-user --user 0 "$PKG" >/dev/null 2>&1 || true
    framework am force-stop --user 0 "$PKG" >/dev/null 2>&1 || true
fi

/system/bin/sh "$MODDIR/bin/callback.sh" on
gms_pid=$(pidof com.google.android.gms || true)
printf '%s\n' "$gms_pid" > "$AUTH/gms-pid"
boot_id > "$AUTH/boot"
startup_trace PATCH_AUTH_READY
echo "CALLBACK_AUTH_PRIMED evidence=$evidence gms_pid=$gms_pid"
