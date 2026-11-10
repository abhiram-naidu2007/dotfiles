#!/bin/bash
# Summon the desktop cat, or send it away if it is already out.
pkill -x mochi || exec setsid "$HOME/.local/bin/mochi"
