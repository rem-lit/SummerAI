#!/usr/bin/env bash
# Mermaid charts for a power-limit sweep, from the summary.md written by
# power-limit.sh. Prints Markdown to paste into the results page.
#
# Usage: scripts/bench/power-limit-charts.sh <results dir>/summary.md
set -euo pipefail

(( $# == 1 )) || { echo "usage: $0 <summary.md>" >&2; exit 2; }
[[ -r "$1" ]] || { echo "cannot read $1" >&2; exit 2; }

# Table rows only, by increasing limit. Columns after splitting on "|":
# 2 limit, 3 prompt tok/s, 4 W, 5 tok/J, 6 generation tok/s, 7 W, 8 tok/J.
rows=$(grep -E '^\| [0-9]+ \|' "$1" | sort -t'|' -k2,2n)
[[ -n "$rows" ]] || { echo "no result rows in $1" >&2; exit 2; }

chart() { # chart <column> <title> <y-axis label>
  awk -F'|' -v col="$1" -v title="$2" -v ylabel="$3" '
    { x = x sep $2 + 0; split($col, v, " "); y = y sep v[1] + 0
      if (v[1] + 0 > max) max = v[1] + 0; sep = ", " }
    END {
      # Axis from zero to a round value above the maximum.
      e = log(max) / log(10); f = int(e); if (f > e) f--
      step = 10 ^ f / 2
      top = step * (int(max * 1.1 / step) + 1)
      print "```mermaid"
      print "---"
      print "config:"
      print "  themeVariables:"
      print "    xyChart:"
      print "      plotColorPalette: \"#2a78d6\""
      print "---"
      print "xychart-beta"
      print "  title \"" title "\""
      print "  x-axis \"Limite de puissance (W)\" [" x "]"
      print "  y-axis \"" ylabel "\" 0 --> " top
      print "  bar [" y "]"
      print "```"
    }' <<<"$rows"
}

chart 6 "Vitesse de génération" "Jetons par seconde"
echo
chart 8 "Efficacité de la génération" "Jetons par joule"
echo
chart 3 "Vitesse de traitement du prompt" "Jetons par seconde"
echo
chart 5 "Efficacité du traitement du prompt" "Jetons par joule"
