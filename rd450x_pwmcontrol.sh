#!/bin/bash

trap daemon_stop SIGINT SIGTERM

if [ "${EUID}" -ne 0 ]; then
    echo "Root privileges needed to run ipmitool."
    exit 1
fi

if ! command -v ipmitool &>/dev/null; then
    echo "ipmitool not installed."
    exit 1
fi

function fan_set() {
    ipmitool raw 0x2e 0x30 0x00 "$1" "$2" &> /dev/null
    sleep 1
}

pwm_calc() {
    # TEMP_MAX = 85 
    awk "BEGIN { print int((($1-20)^2)/42.25) }"
}

declare -A fan_sensors=(
    # $1          Value
    # -----------------
    # ALL         00
    # SYS_FAN1    01
    # SYS_FAN2    02
    # SYS_FAN3    03
    # SYS_FAN4    04
    # CPU_FAN1    05
    # CPU_FAN2    06
    ["04"]="/sys/class/hwmon/hwmon0/temp1_input"
    ["05"]="/sys/class/thermal/thermal_zone0/temp"
    ["06"]="/sys/class/thermal/thermal_zone1/temp"
)

function daemon() {
    while true; do
        for fan_id in "${!fan_sensors[@]}"; do
            sensor_file="${fan_sensors[$fan_id]}"
            if [ -f "$sensor_file" ]; then
                temp=$(awk '{print int($1/1000)}' "$sensor_file")
                pwm=$(pwm_calc "$temp")
                fan_set "$fan_id" "$pwm"
            fi
        done
        sleep 2
    done
}

function daemon_stop() {
    fan_set "00" "100"
    exit 0
}

daemon
