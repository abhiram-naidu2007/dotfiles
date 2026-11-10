#!/bin/bash
# Click on the date: this month as a notification, today marked.
today=$(date +%-d)
body=$(cal | tail -n +2 | sed -E "s/(^| )($today)( |$)/\\1<b><u>\\2<\/u><\/b>\\3/")
dunstify -r 9920 -a calendar -t 8000 "$(date '+%A, %d %B %Y')" "<span font='JetBrainsMono Nerd Font 11'>$body</span>"
