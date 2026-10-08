#!/usr/bin/env bash
# Download weights with:
#   uv run hf download sokrypton/af3-any-model --local-dir /cluster/project/beltrao/shared/alphafold3/models-af3-any-model-hf
#
# Lay out DEST the way run_alphafold.py expects, as hard links to the files
# in SRC (the `hf download --local-dir` copy):
#
#   DEST/protenix2-int8/protenix2.int8.bin.zst
#     == SRC/protenix/protenix2.int8.bin.zst   (same inode, no extra space)
#
# SRC and DEST must be on the same filesystem. DEST stays valid even if
# SRC is moved or deleted.
#
# Usage:  ./setup_hf_weights.sh SRC DEST
#
# Example:
#   ./setup_hf_weights.sh $SHARED/alphafold3/models-af3-any-model-hf $SHARED/alphafold3/models-af3-any-model
#
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 SRC DEST" >&2; exit 1; }
[ -d "$1" ]  || { echo "no $1 -- run hf download first" >&2; exit 1; }

SRC="$(cd "$1" && pwd)"
mkdir -p "$2"
DEST="$(cd "$2" && pwd)"

n=0
# link <target-file> <subdir of DEST>
link() {
  local dir="$DEST/$2"
  mkdir -p "$dir"
  ln -f "$1" "$dir/$(basename "$1")"
  n=$((n + 1))
}

# weights and language models -> <model>[-fp16|-int8]/<file>
for f in "$SRC"/*/*.bin.zst; do
  [ -e "$f" ] || continue
  name=$(basename "$f"); model=${name%%.*}
  case "$name" in
    *.fp16.bin.zst) d=$model-fp16 ;;
    *.int8.bin.zst) d=$model-int8 ;;
    *)              d=$model ;;
  esac
  link "$f" "$d"
done

# ESMFold2 shims -> every precision folder of that model
for f in "$SRC"/*/*.lm.npz; do
  [ -e "$f" ] || continue
  name=$(basename "$f"); model=${name%%.*}
  for d in "$DEST/$model" "$DEST/$model"-*; do
    if [ -d "$d" ]; then
      link "$f" "$(basename "$d")"
    fi
  done
done

echo "created $n links in $DEST"
