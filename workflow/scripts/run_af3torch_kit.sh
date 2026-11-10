#!/usr/bin/env bash
# Runs INSIDE Anthropic's af3_torch kit image in place of run_alphafold_shard_default.sh
# (config: alphafold3.predictions.run_alphafold_wrapper: run_af3torch_kit.sh). See examples/af3torch_kit.
#
# Takes the arguments alphafold3_datafill_predictions passes to run_alphafold.py and hands them to the kit's `pred`.
# Input names: af3io data-fill writes <hash>_data.json, but the kit names its output after the input file stem, so
# every input is staged as <hash>.json (symlink) and the output lands in <hash>/ as the rule expects.
#
# Environment (pass with --env in singularity_args):
#   AF3TORCH_KIT_MODE    off | exact | fast | big   (default big: lowest peak memory)
#   AF3TORCH_KIT_CONFIG  kit card file (default h100; every kernel decision keys on the real device)
# --allow-partial: outside the kit's certified sm80/sm90 a kernel may refuse by name; the kit reports it instead of exit 3.
set -euo pipefail
echo "[run_af3torch_kit] $(date -Is) host=$(hostname) mode=${AF3TORCH_KIT_MODE:-big} config=${AF3TORCH_KIT_CONFIG:-h100}"
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv,noheader 2>/dev/null || echo "nvidia-smi unavailable"
echo "[run_af3torch_kit] args: $*"

STAGE_ROOT="${TMPDIR:-/tmp}/af3torch_kit_inputs"
ARGS=()
for a in "$@"; do
    case "$a" in
        --input_dir=*)
            src="${a#--input_dir=}"
            mkdir -p "$STAGE_ROOT"
            n=0
            for f in "$src"/*.json; do
                [[ -f "$f" ]] || continue
                b="$(basename "$f" .json)"; b="${b%_data}"
                ln -sfn "$f" "$STAGE_ROOT/$b.json"; n=$((n + 1))
            done
            [[ "$n" -gt 0 ]] || { echo "[run_af3torch_kit] ERROR: no *.json under $src" >&2; exit 2; }
            echo "[run_af3torch_kit] staged $n input(s) from $src as <hash>.json in $STAGE_ROOT"
            ARGS+=("--input_dir=$STAGE_ROOT") ;;
        *) ARGS+=("$a") ;;
    esac
done

cd /kit/af3_torch
exec bash run.sh pred --config "${AF3TORCH_KIT_CONFIG:-h100}" --mode "${AF3TORCH_KIT_MODE:-big}" --allow-partial "${ARGS[@]}"
