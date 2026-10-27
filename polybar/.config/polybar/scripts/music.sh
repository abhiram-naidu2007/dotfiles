#!/bin/sh
# Event-driven (no polling). Empty output when limusic is not running.
exec playerctl -p limusic --follow metadata --format '{{artist}} · {{title}}' 2>/dev/null
