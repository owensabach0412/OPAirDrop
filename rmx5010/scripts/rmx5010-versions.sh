#!/system/bin/sh
# 只读：驱动/固件版本、OShare 接收相关组件、Mosey 相关包
OUT=/data/local/tmp/opairdrop-versions.txt
: > "$OUT"
echo "===== dmesg 版本线索 =====" >> "$OUT"
dmesg | grep -iE 'qcacld|driver version|WLAN\.GNG|fw version|firmware version|wlan.*ver' | tail -n 40 >> "$OUT" 2>&1
echo "" >> "$OUT"
echo "===== 内核 cmdline =====" >> "$OUT"
cat /proc/cmdline >> "$OUT" 2>&1
echo "" >> "$OUT"
echo "===== OShare 与接收/传输相关的组件 =====" >> "$OUT"
dumpsys package com.coloros.oshare 2>/dev/null | grep -iE 'com\.oplus\.oshare\.[A-Za-z.]*(Service|Server|Receiver|Activity)' | sort -u | head -n 60 >> "$OUT"
echo "" >> "$OUT"
echo "===== 搜索 Mosey / QuickShare / Nearby 相关包 =====" >> "$OUT"
pm list packages 2>/dev/null | grep -iE 'mosey|quickshare|nearby|share' >> "$OUT" 2>&1
echo "" >> "$OUT"
echo "===== system_ext/priv-app 里与共享相关的目录 =====" >> "$OUT"
ls /system/system_ext/priv-app 2>/dev/null | head -n 40 >> "$OUT"
ls /system_ext/priv-app 2>/dev/null | head -n 40 >> "$OUT" 2>&1
echo "" >> "$OUT"
echo "===== 已加载的 OShare 服务进程 =====" >> "$OUT"
ps -A 2>/dev/null | grep -i oshare >> "$OUT"
echo "" >> "$OUT"
echo "DONE"
