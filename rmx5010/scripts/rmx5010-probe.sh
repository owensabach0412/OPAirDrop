#!/system/bin/sh
# RMX5010 (realme GT7 Pro) 移植前取证脚本（只读）
# 用法：adb push rmx5010-probe.sh /data/local/tmp/
#       adb shell su -c "sh /data/local/tmp/rmx5010-probe.sh"
# 结果：/data/local/tmp/opairdrop-probe.txt

OUT=/data/local/tmp/opairdrop-probe.txt
: > "$OUT" 2>/dev/null || OUT=/sdcard/opairdrop-probe.txt
: > "$OUT"
say() { echo "$@" >> "$OUT"; }
sec() { echo "" >> "$OUT"; echo "===== $* =====" >> "$OUT"; }
run() { echo "\$ $*" >> "$OUT"; "$@" >> "$OUT" 2>&1; }
line() { echo "$*" >> "$OUT"; }

sec "0. 环境"
line "whoami: $(id)"
line "selinux: $(getenforce)"
line "uname: $(uname -a)"
line "pagesize: $(getconf PAGE_SIZE)"

sec "1. 设备与系统"
for p in ro.product.model ro.product.name ro.product.device ro.product.brand \
         ro.product.manufacturer ro.product.vendor.brand ro.product.vendor.manufacturer \
         ro.board.platform ro.soc.model ro.soc.manufacturer \
         ro.build.version.release ro.build.version.sdk ro.build.display.id \
         ro.build.fingerprint ro.vendor.build.fingerprint \
         ro.vendor.oplus.market.enname ro.product.marketname \
         ro.boot.hardware ro.boot.hardware.sku ro.boot.project_name ro.build.type ro.debuggable; do
    line "$p=$(getprop "$p")"
done

sec "2. 内核身份"
line "release: $(uname -r)"
case "$(uname -r)" in
    6.6.118*) line "WARN: 内核 release 含 6.6.118" ;;
    6.6.89*)  line "OK: 6.6.89 家族" ;;
    *)        line "NOTE: 其它内核 $(uname -r)" ;;
esac
line "--- /proc/version ---"
cat /proc/version >> "$OUT" 2>&1
line "--- /proc/config.gz ---"
if [ -r /proc/config.gz ]; then
    zcat /proc/config.gz > /data/local/tmp/opairdrop-config.txt 2>/dev/null \
        && line "已导出 /data/local/tmp/opairdrop-config.txt"
else
    line "无 /proc/config.gz（或不可读）"
fi

sec "3. 关键模块（/proc/modules）"
for m in qca_cld3_peach_v2 qca_cld3_peach cfg80211 mac80211 cnss2 cnss_utils cnss_nl cnss_prealloc ipam sched-walt qcom_iommu_util wonder opairshare_wonder_provider; do
    l=$(grep "^$m " /proc/modules 2>/dev/null)
    [ -n "$l" ] && line "$l"
done
line "--- 前 60 行 ----"
head -n 60 /proc/modules >> "$OUT" 2>&1

sec "4. 厂商模块文件"
ls -l /vendor/lib/modules/ 2>/dev/null | grep -Ei 'qca|mac80211|cfg80211|cnss|ipam|walt' >> "$OUT" 2>&1
line "--- 目录是否存在 ---"
for d in /vendor/lib/modules /vendor/lib/modules/1.1 /system/lib/modules; do
    [ -d "$d" ] && line "dir OK: $d"
done

sec "5. 已加载模块 build-id"
for d in /sys/module/*; do
    n=${d##*/}
    case "$n" in qca_cld3*|mac80211|cfg80211|cnss*) ;; *) continue;; esac
    id=$(od -An -tx1 "$d/notes/.note.gnu.build-id" 2>/dev/null | tr -d ' \n')
    line "NOTE_$n=$id"
done

sec "6. WLAN HAL / 服务"
getprop 2>/dev/null | grep -E 'init\.svc\..*(wifi|cnss|wlan)' >> "$OUT" 2>&1
line "--- dumpsys wifi（前 40 行）---"
dumpsys wifi 2>/dev/null | head -n 40 >> "$OUT"

sec "7. WLAN 固件与驱动线索"
ls -l /vendor/firmware/ 2>/dev/null | head -n 30 >> "$OUT"
getprop 2>/dev/null | grep -iE 'wlan|wifi|cnss' >> "$OUT" 2>&1

sec "8. 关键 App"
for p in com.google.android.mosey com.coloros.oshare com.oplus.oshare; do
    line "--- $p ---"
    pm path "$p" >> "$OUT" 2>&1
    pm list packages 2>/dev/null | grep -F "$p" >> "$OUT" 2>&1
done
line "--- Mosey 版本 ---"
dumpsys package com.google.android.mosey 2>/dev/null | grep -E 'versionName|versionCode|codePath|primaryCpuAbi' >> "$OUT"
line "--- Mosey 全部分包 sha256 ---"
for f in $(pm path com.google.android.mosey 2>/dev/null | sed 's/^package://'); do
    [ -f "$f" ] && sha256sum "$f" >> "$OUT" 2>&1
done
line "--- OShare 版本 ---"
dumpsys package com.coloros.oshare 2>/dev/null | grep -E 'versionName|versionCode|codePath' >> "$OUT"

sec "9. OShare 组件"
dumpsys package com.coloros.oshare 2>/dev/null | grep -iE 'OShareServer|oshare' | head -n 15 >> "$OUT"

sec "10. Root / LSPosed"
for p in /data/adb/ksud /data/adb/magisk /data/adb/apd /data/adb/modules /data/adb/lspd; do
    [ -e "$p" ] && line "exists: $p"
done
pm list packages 2>/dev/null | grep -iE 'lsposed|mosey|oshare|quickshare' >> "$OUT" 2>&1

sec "11. 日志线索"
dmesg 2>/dev/null | grep -iE 'wlan|cnss|cfg80211|mac80211|module' | tail -n 50 >> "$OUT"
dmesg 2>/dev/null | grep -i avc | tail -n 15 >> "$OUT"

sec "12. 工具可用性"
for t in insmod rmmod lsmod dmesg readelf toybox; do
    w=$(command -v "$t" 2>/dev/null)
    line "$t -> ${w:-NOT FOUND}"
done

line ""
line "DONE"
echo "DONE -> $OUT"
