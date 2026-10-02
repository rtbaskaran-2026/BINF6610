#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p logs

ARRAY_ID=$(sbatch --parsable -p courses -A binf6610.202710 01_persample.sbatch)
echo "submitted per-sample array: ${ARRAY_ID}"

COHORT_ID=$(sbatch --parsable --dependency="afterok:${ARRAY_ID}" --kill-on-invalid-dep=yes 02_cohort.sbatch)
echo "submitted cohort job: ${COHORT_ID} (depends on ${ARRAY_ID})"add
