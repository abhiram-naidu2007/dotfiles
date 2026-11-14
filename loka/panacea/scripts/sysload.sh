#!/bin/bash

fast=0
[ "$1" = "--fast" ] || [ "$1" = "--desktop" ] && fast=1

cpu=""
tcpu=""
gpu=""
tgpu=""

if [ "$fast" -eq 0 ]; then
    read -r _ a b c prev_idle rest < /proc/stat
    prev_total=$((a + b + c + prev_idle))
    for x in $rest; do prev_total=$((prev_total + x)); done

    sleep 0.3

    read -r _ a b c idle rest < /proc/stat
    total=$((a + b + c + idle))
    for x in $rest; do total=$((total + x)); done

    dt=$((total - prev_total))
    di=$((idle - prev_idle))
    [ "$dt" -gt 0 ] && cpu=$(( (dt - di) * 100 / dt ))
fi

mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2}
           END{ if (t > 0) printf "%d", (t - a) * 100 / t }' /proc/meminfo)

disk=$(df -k / 2>/dev/null | awk 'NR==2 {if ($2>0) printf "%d", $3*100/$2}')

if [ "$fast" -eq 0 ]; then
    for h in /sys/class/hwmon/hwmon*; do
        case "$(cat "$h/name" 2>/dev/null)" in
            k10temp|coretemp|zenpower|cpu_thermal|acpitz_cpu)
                v=$(cat "$h/temp1_input" 2>/dev/null)
                [ -n "$v" ] && tcpu=$((v / 1000))
                break
                ;;
        esac
    done

    for d in /sys/class/drm/card*/device; do
        [ -r "$d/gpu_busy_percent" ] || continue
        gpu=$(cat "$d/gpu_busy_percent" 2>/dev/null)
        break
    done
    for h in /sys/class/hwmon/hwmon*; do
        case "$(cat "$h/name" 2>/dev/null)" in
            amdgpu|nouveau|radeon|i915|nvidia)
                v=$(cat "$h/temp1_input" 2>/dev/null)
                [ -n "$v" ] && tgpu=$((v / 1000))
                break
                ;;
        esac
    done

fi

printf '%s|%s|%s|%s|%s|%s\n' "$cpu" "$mem" "$gpu" "$tcpu" "$tgpu" "$disk"
