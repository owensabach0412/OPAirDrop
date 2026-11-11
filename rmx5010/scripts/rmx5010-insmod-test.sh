#!/system/bin/sh
# RMX5010 dry-run: 在原厂模块仍加载的前提下，验证 OPAirDrop 的四个 .ko 的
# vermagic / 符号 CRC / 同名冲突行为。只读验证，不替换任何驱动。
# 结果：/data/local/tmp/opairdrop-insmod.txt

D=/data/local/tmp/opairdrop-kernel
OUT=/data/local/tmp/opairdrop-insmod.txt
: > "$OUT"

log() { echo "$@" >> "$OUT"; }
sec() { echo "" >> "$OUT"; echo "===== $* =====" >> "$OUT"; }
tail_dmesg() { dmesg 2>/dev/null | tail -n "$1" >> "$OUT"; }

sec "环境"
log "kernel: $(uname -r)"
log "tainted: $(cat /proc/sys/kernel/tainted 2>/dev/null)"
log "stock modules:"
grep -E '^(qca_cld3_peach_v2|mac80211|cfg80211|cnss2) ' /proc/modules >> "$OUT" 2>&1
log "wonder 已加载? $(grep -c '^wonder ' /proc/modules 2>/dev/null)"
log "provider 已加载? $(grep -c '^oneplus13_wonder_provider ' /proc/modules 2>/dev/null)"

sec "各 .ko 的 vermagic / 构建信息（readelf）"
for m in mac80211 qca_cld3_peach_v2 wonder oneplus13_wonder_provider; do
    f="$D/$m.ko"
    log "--- $m ($(wc -c < "$f" 2>/dev/null) bytes) ---"
    readelf -n "$f" 2>/dev/null | grep -i 'build id' >> "$OUT"
done

sec "1) insmod mac80211.ko（同名，预期 EEXIST 或 CRC 报错）"
insmod "$D/mac80211.ko" >> "$OUT" 2>&1
log "rc=$?"
tail_dmesg 30

sec "2) insmod qca_cld3_peach_v2.ko（同名，预期 EEXIST 或 CRC 报错）"
insmod "$D/qca_cld3_peach_v2.ko" >> "$OUT" 2>&1
log "rc=$?"
tail_dmesg 40

sec "3) insmod wonder.ko（无同名冲突，可能真加载）"
insmod "$D/wonder.ko" >> "$OUT" 2>&1
log "rc=$?"
tail_dmesg 30
if grep -q '^wonder ' /proc/modules 2>/dev/null; then
    log "wonder 已加载，执行 rmmod"
    rmmod wonder >> "$OUT" 2>&1
    log "rmmod rc=$?"
    tail_dmesg 10
fi

sec "4) insmod oneplus13_wonder_provider.ko（无同名冲突）"
insmod "$D/oneplus13_wonder_provider.ko" >> "$OUT" 2>&1
log "rc=$?"
tail_dmesg 20
if grep -q '^oneplus13_wonder_provider ' /proc/modules 2>/dev/null; then
    log "provider 已加载，执行 rmmod"
    rmmod oneplus13_wonder_provider >> "$OUT" 2>&1
    log "rmmod rc=$?"
fi

sec "收尾状态"
log "tainted: $(cat /proc/sys/kernel/tainted 2>/dev/null)"
log "残留 wonder: $(grep -c '^wonder ' /proc/modules 2>/dev/null)"
log "残留 provider: $(grep -c '^oneplus13_wonder_provider ' /proc/modules 2>/dev/null)"
log "wlan 接口:"
ip -o link 2>/dev/null | awk '{print $2}' >> "$OUT" 2>&1
log "wifi 状态: $(cmd wifi status 2>/dev/null | head -n 3)"
log ""
log "DONE"
echo "DONE -> $OUT"
