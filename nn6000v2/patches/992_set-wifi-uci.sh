#!/bin/sh

board_name="$(cat /tmp/sysinfo/board_name 2>/dev/null)"

configure_wifi() {
    local radio="$1"
    local band="$2"
    local channel="$3"
    local htmode="$4"
    local txpower="$5"
    local ssid="$6"
    local key="$7"
    local encryption="${8:-psk2+ccmp}"

    local current_encryption
    current_encryption="$(uci -q get "wireless.default_radio${radio}.encryption")"

    # 已有有效无线配置时不覆盖用户配置
    if [ -n "$current_encryption" ] && [ "$current_encryption" != "none" ]; then
        return 0
    fi

    uci -q batch <<EOF
set wireless.radio${radio}.band='${band}'
set wireless.radio${radio}.channel='${channel}'
set wireless.radio${radio}.htmode='${htmode}'
set wireless.radio${radio}.mu_beamformer='1'
set wireless.radio${radio}.country='US'
set wireless.radio${radio}.txpower='${txpower}'
set wireless.radio${radio}.cell_density='0'
set wireless.radio${radio}.disabled='0'
set wireless.default_radio${radio}.ssid='${ssid}'
set wireless.default_radio${radio}.encryption='${encryption}'
set wireless.default_radio${radio}.key='${key}'
set wireless.default_radio${radio}.ieee80211k='1'
set wireless.default_radio${radio}.time_advertisement='2'
set wireless.default_radio${radio}.time_zone='CST-8'
set wireless.default_radio${radio}.bss_transition='1'
set wireless.default_radio${radio}.wnm_sleep_mode='1'
set wireless.default_radio${radio}.wnm_sleep_mode_no_keys='1'
EOF
}

case "$board_name" in
    link,nn6000-v2)
        configure_wifi 0 '5g' 157 'HE80' 18 '500/5' '88888888'
        configure_wifi 1 '2g' 1 'HT20' 18 '500/5' '88888888'

        # 首次启动默认启用 2.4GHz 与 5GHz
        uci -q set wireless.radio0.disabled='0'
        uci -q set wireless.radio1.disabled='0'
        uci -q commit wireless
        /etc/init.d/network restart
        ;;
    *)
        exit 0
        ;;
esac
