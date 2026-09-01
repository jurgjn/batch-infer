#!/usr/bin/env bash
# Prints the commands for folding one sequence with the OpenFold3 openbind
# weights - the script form of ../alphafold3_of3_weights/run_alphafold.ipynb.
# It runs nothing itself: each batch-infer start queues a SLURM job and returns
# immediately, so the steps have to be run one at a time, checking
# `batch-infer status` before moving on.
#
#   ./run_alphafold.sh [config.yaml]
set -eu

CONFIG=${1:-config.yaml}
ACCESSION=o00244   # ATOX1
# The precache comes from the config, and the sequence from the precache entry
# that will supply its MSAs, so nothing below is pasted in by hand.
PRECACHE=$(sed -n 's/.*--data_dir=\([^ ]*\).*/\1/p' "$CONFIG")
DATA_JSON=$PRECACHE/${ACCESSION}_data.json.gz
SEQUENCE=$(python3 -c \
    "import gzip,json,sys; print(json.load(gzip.open(sys.argv[1],'rt'))['sequences'][0]['protein']['sequence'])" \
    "$DATA_JSON")

cat <<EOF
# Run these from $(pwd), on a login node, with the batch-infer venv activated.
# Each 'batch-infer start' submits a job; wait for it to finish before the next.

# Container and parameters for the OpenFold3 weights
cat $CONFIG
$([ "$CONFIG" = config.yaml ] || echo "cp $CONFIG config.yaml   # batch-infer reads ./config.yaml")

# The precache entry that will supply the MSAs
af3io input-show $DATA_JSON

# Create input JSON for $ACCESSION. alphafold3_msas/ is where the data pipeline
# writes; it has to exist even when every sequence is already in the precache,
# because the predictions step passes --data_dir=alphafold3_msas regardless.
mkdir -p alphafold3_jsons alphafold3_msas
af3io input-create alphafold3_jsons/$ACCESSION.json --sequence $SEQUENCE

# Find missing sequences
batch-infer start alphafold3_datafill_missing
batch-infer status

# Run the data pipeline only for the missing sequences
batch-infer start alphafold3_datafill_msas
batch-infer status

# Run predictions, creating temporary data pipeline output on local scratch as-needed
batch-infer start alphafold3_datafill_predictions
batch-infer status

# Predictions stored as zip-compressed archives under alphafold3_predictions/
ls -l alphafold3_predictions/
EOF
