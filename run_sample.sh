#!/bin/bash
set -euo pipefail

SHEET="$1"
OUT="$2"
SAMPLE="$3"
LAST="${4:-}"

PIPE_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

source "${PIPE_DIR}/lib/common.sh"
for f in "${PIPE_DIR}"/stages/*.sh; do source "$f"; done
setup_dirs

STAGES=(validate qc_raw trim align postprocess quantify)   # stages 0-5 ONLY

# Refuse to run cohort stages 6-9 even if asked
case "$LAST" in
    merge|analyze|qc_report|publish)
        die "run_sample.sh only runs stages 0-5 (validate through quantify); ${LAST} is a cohort stage — use run_pipeline.sh"
        ;;
esac

known=0
for s in "${STAGES[@]}"; do
    [[ "$s" == "$LAST" ]] && known=1
done
[[ -z "$LAST" || "$known" -eq 1 ]] || die "unknown stage: ${LAST}"

[[ -n "$SAMPLE" ]] || die "run_sample.sh requires a sample id as the third argument"

n=0
for stage in "${STAGES[@]}"; do
    log "===== stage ${n} : ${stage} (sample: ${SAMPLE}) ====="
    "stage_${stage}"
    [[ "$stage" == "$LAST" ]] && break
    n=$(( n + 1 ))
done
