#!/bin/bash
set -euo pipefail

SHEET="$1"
OUT="$2"
LAST="${3:-}"
SAMPLE=""

PIPE_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

source "${PIPE_DIR}/lib/common.sh"
for f in "${PIPE_DIR}"/stages/*.sh; do source "$f"; done
setup_dirs

STAGES=(validate qc_raw trim align postprocess quantify merge analyze qc_report publish)

known=0
for s in "${STAGES[@]}"; do
    [[ "$s" == "$LAST" ]] && known=1
done
[[ -z "$LAST" || "$known" -eq 1 ]] || die "unknown stage: ${LAST}"

n=0
for stage in "${STAGES[@]}"; do
    log "===== stage ${n} : ${stage} ====="
    "stage_${stage}"
    [[ "$stage" == "$LAST" ]] && break
    n=$(( n + 1 ))
done
