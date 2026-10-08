#!/usr/bin/env bash
set -euo pipefail

SHEET="$1"
REF="$2"
REF_INDEX="$3"
REF_DICT="$4"

problems=0

[[ -s "$REF" ]]       || { echo "no reference at ${REF}" >&2; (( ++problems )); }
[[ -s "$REF_INDEX" ]] || { echo "no .fai index at ${REF_INDEX}" >&2; (( ++problems )); }

while IFS=, read -r id cond rep lib_type r1 r2; do
    [[ "$id" == "sample_id" ]] && continue   # skip header

    r1_name=$(basename "$r1")
    r2_name=""
    [[ -n "$r2" ]] && r2_name=$(basename "$r2")

    [[ -s "$r1_name" ]] || { echo "$id: R1 missing or empty: $r1_name" >&2; (( ++problems )); }

    if [[ "$lib_type" == paired && -n "$r2_name" ]]; then
        [[ -s "$r2_name" ]] || { echo "$id: paired but R2 missing: $r2_name" >&2; (( ++problems )); }
    fi

    if [[ -s "$r1_name" ]]; then
        gzip -t "$r1_name" 2>/dev/null || { echo "$id: R1 is not a valid gzip file: $r1_name" >&2; (( ++problems )); }
    fi
    if [[ "$lib_type" == paired && -n "$r2_name" && -s "$r2_name" ]]; then
        gzip -t "$r2_name" 2>/dev/null || { echo "$id: R2 is not a valid gzip file: $r2_name" >&2; (( ++problems )); }
    fi
done < "$SHEET"

(( problems == 0 )) || { echo "validation failed with ${problems} problem(s)" >&2; exit 65; }
echo "validation passed" >&2
