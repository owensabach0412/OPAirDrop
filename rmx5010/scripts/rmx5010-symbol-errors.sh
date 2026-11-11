#!/system/bin/sh
OUT=/data/local/tmp/opairdrop-symbol-errors.txt
: > "$OUT"
echo "== unknown symbol / version 错误 ==" >> "$OUT"
dmesg | grep -iE 'unknown symbol|disagrees about version|module_layout|version magic|no symbol version' | tail -n 60 >> "$OUT" 2>&1
echo "" >> "$OUT"
echo "== 最近 qca/mac80211 加载日志 ==" >> "$OUT"
dmesg | grep -iE 'qca_cld3_peach_v2|mac80211' | tail -n 60 >> "$OUT" 2>&1
echo "" >> "$OUT"
echo "== 当前模块 ==" >> "$OUT"
grep -E '^(qca_cld3_peach_v2|mac80211|cfg80211) ' /proc/modules >> "$OUT" 2>&1
echo "DONE"
