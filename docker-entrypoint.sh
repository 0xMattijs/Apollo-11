#!/usr/bin/env bash
# Apollo-11 · Virtual AGC container entrypoint
set -euo pipefail

VAGC=${VAGC:-/opt/virtualagc}
APOLLO=${APOLLO:-/opt/apollo11}
YAYUL="$VAGC/yaYUL/yaYUL"
YAAGC="$VAGC/yaAGC/yaAGC"
YADSKY="$VAGC/yaDSKY2/yaDSKY2"

# The core ropes we assemble and run are the maintained, compilable Apollo 11
# sources that ship with the Virtual AGC toolchain. This repository's archival
# transcription (kept under $APOLLO for reference/diffing) has drifted over the
# years and no longer assembles with the current yaYUL — see `agc diff`.
rope_dir() {    # canonical, buildable source
  case "$1" in
    cm|CM|comanche|Comanche055) echo "$VAGC/Comanche055" ;;
    lm|LM|luminary|Luminary099) echo "$VAGC/Luminary099" ;;
    *) echo "unknown vehicle '$1' (use 'cm' or 'lm')" >&2; return 2 ;;
  esac
}

archive_dir() { # this repository's archival source
  case "$1" in
    cm|CM|comanche|Comanche055) echo "$APOLLO/Comanche055" ;;
    lm|LM|luminary|Luminary099) echo "$APOLLO/Luminary099" ;;
    *) echo "unknown vehicle '$1' (use 'cm' or 'lm')" >&2; return 2 ;;
  esac
}

cfg_for() {
  case "$1" in cm|CM|comanche|Comanche055) echo CM.ini ;; *) echo LM.ini ;; esac
}

assemble_one() {
  local veh d; veh="$1"; d=$(rope_dir "$veh")
  echo ">> Assembling ${veh}: $d/MAIN.agc"
  ( cd "$d" && "$YAYUL" --unpound-page MAIN.agc > MAIN.agc.lst )
  if [ -s "$d/MAIN.agc.bin" ]; then
    echo ">> OK   $d/MAIN.agc.bin ($(wc -c < "$d/MAIN.agc.bin") bytes)"
  else
    echo ">> FAIL no binary produced for ${veh}; see $d/MAIN.agc.lst" >&2
    return 1
  fi
}

cmd=${1:-help}; shift || true

case "$cmd" in
  assemble)
    target=${1:-all}
    if [ "$target" = all ]; then assemble_one cm; assemble_one lm
    else assemble_one "$target"; fi
    ;;

  run)
    veh=${1:-lm}; d=$(rope_dir "$veh"); cfg=$(cfg_for "$veh")
    rope="$d/MAIN.agc.bin"
    [ -f "$rope" ] || { echo "Rope not found: $rope — run 'agc assemble $veh' first." >&2; exit 1; }
    echo ">> yaAGC: loading $rope (listening on TCP 19697-19706)"
    "$YAAGC" "$rope" &
    agc_pid=$!
    trap 'kill "$agc_pid" 2>/dev/null || true' EXIT
    sleep 1
    if [ -z "${DISPLAY:-}" ]; then
      cat >&2 <<EOF
!! DISPLAY is not set, so the yaDSKY2 GUI cannot open.
   Re-run with an X server attached, e.g. on a Linux host:
     xhost +local:docker
     docker run --rm -it -e DISPLAY=\$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \\
        apollo-agc run $veh
   yaAGC is now running headless; press Ctrl-C to stop.
EOF
      wait "$agc_pid"
    else
      echo ">> yaDSKY2: opening $cfg panel"
      ( cd "$VAGC/yaDSKY2" && "$YADSKY" --cfg="$cfg" )
    fi
    ;;

  emulator|yaAGC)
    veh=${1:-lm}; d=$(rope_dir "$veh")
    exec "$YAAGC" "$d/MAIN.agc.bin"
    ;;

  dsky|yaDSKY2)
    veh=${1:-lm}; cfg=$(cfg_for "$veh")
    cd "$VAGC/yaDSKY2" && exec "$YADSKY" --cfg="$cfg"
    ;;

  diff)
    veh=${1:-cm}; a=$(archive_dir "$veh"); c=$(rope_dir "$veh")
    echo ">> Comparing this repo's archival source (<) with the canonical"
    echo "   buildable source (>) for ${veh}:"
    echo "   archival : $a"
    echo "   canonical: $c"
    echo "=== differing / missing filenames ==="
    diff <(cd "$a" && ls *.agc) <(cd "$c" && ls *.agc) || true
    ;;

  yaYUL)  exec "$YAYUL" "$@" ;;
  shell|bash) exec /bin/bash ;;

  help|-h|--help)
    cat <<'EOF'
Apollo-11 · Virtual AGC container

Usage: agc <command> [vehicle]

  assemble [cm|lm|all]   Assemble a core rope with yaYUL (default: all)
  run [cm|lm]            Run yaAGC + yaDSKY2 GUI   (needs X11; default: lm)
  emulator [cm|lm]       Run yaAGC only (headless CPU) for the vehicle
  dsky [cm|lm]           Run the yaDSKY2 GUI only (connects to a running yaAGC)
  diff [cm|lm]           Compare this repo's archival source to the canonical one
  yaYUL <args...>        Invoke the raw assembler
  shell                  Drop into a bash shell
  help                   Show this message

Vehicles:  cm = Command Module (Comanche055)  ·  lm = Lunar Module (Luminary099)

NOTE: The assembled/run ropes come from the maintained, compilable Apollo 11
source bundled with the Virtual AGC toolchain. This repository's own archival
transcription is kept at /opt/apollo11 for reference; it has drifted over the
years and no longer assembles with the current yaYUL (`agc diff` shows how).

The DSKY GUI needs an X server. On a Linux host:
  xhost +local:docker
  docker run --rm -it -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix apollo-agc run lm
EOF
    ;;

  *) echo "unknown command '$cmd' — try 'agc help'" >&2; exit 1 ;;
esac
