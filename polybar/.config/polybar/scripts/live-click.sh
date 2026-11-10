#!/bin/bash
# Click on the live button: moves / holds still; with a normal picture shown, open the picker.
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rice"
s=$(cat "$STATE/scene" 2>/dev/null)
if [ -z "$s" ] || [ "$s" = picture ]; then exec ~/.local/bin/rice pick; else exec ~/.local/bin/rice live toggle; fi
