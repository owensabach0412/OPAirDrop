#!/system/bin/sh
# RMX5010 驱动换入测试 v2 —— 严格按 rel131/bin/control.sh:282-298 的顺序：
#   rmmod qca -> insmod provider -> insmod qca(带全套参数) -> rmmod mac80211
#   -> insmod mac80211 -> insmod wonder(带参数)
# 任何失败立即回滚原厂模块。结果：/data/local/tmp/opairdrop-swap2.txt

STOCK=/vendor/lib/modules
OUR=/data/local/tmp/opairdrop-kernel
OUT=/data/local/tmp/opairdrop-swap2.txt
: > "$OUT"

log() { echo "$@" >> "$OUT"; }
sec() { echo "" >> "$OUT"; echo "===== $* =====" >> "$OUT"; }
dt() { dmesg 2>/dev/null | tail -n "$1" >> "$OUT"; }
loaded() { grep -q "^$1 " /proc/modules 2>/dev/null; }

QCA_ARGS="passthru_awdl_addba=1 passthru_awdl_native_rx=1 passthru_ht=1 passthru_fwtype=7 passthru_mon_rings=0 passthru_dry_run=0 passthru_mon_chan_sync=1 passthru_ndi_peer=1 passthru_ndi_no_up=1 passthru_mgmt_bridge=1 passthru_aux_monitor=1 passthru_tx_audit=1 passthru_ndi_fw_authorize=0 passthru_awdl_wmi_raw=1 passthru_awdl_target_auto=1 passthru_awdl_target_enable=1 passthru_awdl_target_auth=2 passthru_native_data_rx=1 passthru_awdl_backpressure=1 passthru_awdl_raw_rx=1 passthru_awdl_rate_mbps=54 passthru_awdl_host_seq=1 passthru_awdl_rx_dedup=1 passthru_awdl_attempts=3 passthru_awdl_rx_auto=1 passthru_awdl_rx_rearm=1 passthru_sta_coexist=3 passthru_sta_regular_rx=1 passthru_sta_action_rx=1 passthru_pas_discovery_actions=1 passthru_awdl_amsdu=2 passthru_awdl_amsdu_max=5 passthru_awdl_amsdu_bytes=7935 passthru_awdl_phy=3 passthru_awdl_mcs=8 passthru_awdl_nss=2 passthru_awdl_collect_us=1000"

rollback() {
    sec "回滚到原厂模块"
    svc wifi disable >/dev/null 2>&1; sleep 2
    /system/bin/stop vendor.wifi_hal_legacy >/dev/null 2>&1; sleep 2
    if loaded wonder; then rmmod wonder >> "$OUT" 2>&1; log "rmmod wonder rc=$?"; fi
    if loaded qca_cld3_peach_v2; then rmmod qca_cld3_peach_v2 >> "$OUT" 2>&1; log "rmmod qca rc=$?"; fi
    if loaded oneplus13_wonder_provider; then rmmod oneplus13_wonder_provider >> "$OUT" 2>&1; log "rmmod provider rc=$?"; fi
    if loaded mac80211; then rmmod mac80211 >> "$OUT" 2>&1; log "rmmod mac80211 rc=$?"; fi
    loaded mac80211 || { insmod "$STOCK/mac80211.ko" >> "$OUT" 2>&1; log "stock mac80211 rc=$?"; }
    loaded qca_cld3_peach_v2 || { insmod "$STOCK/qca_cld3_peach_v2.ko" >> "$OUT" 2>&1; log "stock qca rc=$?"; }
    /system/bin/start vendor.wifi_hal_legacy >/dev/null 2>&1; sleep 3
    svc wifi enable >/dev/null 2>&1; sleep 5
    log "wifi: $(cmd wifi status 2>/dev/null | head -n 1)"
    grep -E '^(qca_cld3_peach_v2|mac80211|cfg80211|oneplus13_wonder_provider) ' /proc/modules >> "$OUT" 2>&1
    dt 20
}

fail() { log "FAIL: $*"; rollback; log "RESULT=FAIL($*)"; echo "FAIL: $*" >> "$OUT"; exit 1; }

sec "开始"
log "kernel=$(uname -r)"
log "wifi=$(cmd wifi status 2>/dev/null | head -n 1)"

sec "1. 关 Wi-Fi / 停 HAL"
svc wifi disable >/dev/null 2>&1
n=0; while [ "$n" -lt 20 ]; do cmd wifi status 2>/dev/null | grep -q 'Wifi is disabled' && break; sleep 1; n=$((n+1)); done
log "wifi=$(cmd wifi status 2>/dev/null | head -n 1) waited=${n}s"
/system/bin/stop vendor.wifi_hal_legacy >/dev/null 2>&1
n=0; while [ "$n" -lt 20 ]; do [ "$(getprop init.svc.vendor.wifi_hal_legacy)" = stopped ] && break; sleep 1; n=$((n+1)); done
log "hal=$(getprop init.svc.vendor.wifi_hal_legacy) waited=${n}s"
[ "$(getprop init.svc.vendor.wifi_hal_legacy)" = stopped ] || fail "HAL not stopped"

sec "2. rmmod 原厂 qca（mac80211 暂时保留，与 control.sh 一致）"
rmmod qca_cld3_peach_v2 >> "$OUT" 2>&1; log "rc=$?"
loaded qca_cld3_peach_v2 && fail "qca still loaded"

sec "3. insmod oneplus13_wonder_provider.ko"
insmod "$OUR/oneplus13_wonder_provider.ko" >> "$OUT" 2>&1; log "rc=$?"
loaded oneplus13_wonder_provider || fail "provider did not load"
dt 10

sec "4. insmod qca_cld3_peach_v2.ko（带 control.sh 的全套参数）"
insmod "$OUR/qca_cld3_peach_v2.ko" $QCA_ARGS >> "$OUT" 2>&1; log "rc=$?"
loaded qca_cld3_peach_v2 || fail "our qca did not load"
dt 40

sec "5. rmmod 原厂 mac80211 / insmod 我们的 mac80211"
rmmod mac80211 >> "$OUT" 2>&1; log "rmmod rc=$?"
loaded mac80211 && fail "mac80211 still loaded"
insmod "$OUR/mac80211.ko" >> "$OUT" 2>&1; log "insmod rc=$?"
loaded mac80211 || fail "our mac80211 did not load"
dt 20

sec "6. insmod wonder.ko"
insmod "$OUR/wonder.ko" physical_name=wondertap0 virtual_name=wonder0 >> "$OUT" 2>&1; log "rc=$?"
loaded wonder || log "WARN: wonder 未加载"
dt 20
log "interfaces:"
ip -o link 2>/dev/null | awk '{print $2}' | tr '\n' ' ' >> "$OUT"; echo "" >> "$OUT"

sec "7. 起 HAL / 开 Wi-Fi"
/system/bin/start vendor.wifi_hal_legacy >/dev/null 2>&1; sleep 3
svc wifi enable >/dev/null 2>&1
n=0; while [ "$n" -lt 45 ]; do cmd wifi status 2>/dev/null | grep -q 'Wifi is enabled' && break; sleep 1; n=$((n+1)); done
log "wifi=$(cmd wifi status 2>/dev/null | head -n 1) waited=${n}s"
log "wlan0=$(ip link show wlan0 2>/dev/null | head -n 1)"

sec "8. 驱动能力参数"
P=/sys/module/qca_cld3_peach_v2/parameters
log "params=$(ls $P 2>/dev/null | wc -l) awdl=$(ls $P 2>/dev/null | grep -cE '^(passthru_|opairshare_)')"
for k in passthru_native_data_rx passthru_awdl_raw_rx passthru_awdl_backpressure passthru_awdl_target_auto passthru_awdl_rx_auto passthru_awdl_rx_rearm passthru_sta_coexist passthru_sta_regular_rx passthru_sta_action_rx passthru_awdl_wmi_raw; do
    log "$k=$(cat $P/$k 2>/dev/null)"
done
log "channel_state=$(cat $P/opairshare_channel_state 2>/dev/null)"
log "wonder0=$(ip link show wonder0 2>/dev/null | head -n 1)"
dt 30

sec "9. 结果"
if cmd wifi status 2>/dev/null | grep -q 'Wifi is enabled' && ip link show wlan0 >/dev/null 2>&1; then
    log "RESULT=OK 驱动换入成功，Wi-Fi 正常"
else
    fail "wifi/wlan0 not healthy"
fi

sec "10. 回滚（测试完恢复原厂）"
rollback
log "FINAL modules:"
grep -E '^(qca_cld3_peach_v2|mac80211|cfg80211|oneplus13_wonder_provider|wonder) ' /proc/modules >> "$OUT" 2>&1
log "FINAL wifi=$(cmd wifi status 2>/dev/null | head -n 1)"
echo "DONE -> $OUT"
