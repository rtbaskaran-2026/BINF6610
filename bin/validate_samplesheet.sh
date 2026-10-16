#!/usr/bin/env bash
set -euo pipefail

SHEET="$1"
REF="$2"
REF_INDEX="$3"
REF_DICT="$4"

SHEET_DIR=$(dirname "$SHEET")

problems=0

[[ -s "$REF" ]]       || { echo "no reference at ${REF}" >&2; (( ++problems )); }
[[ -s "$REF_INDEX" ]] || { echo "no .fai index at ${REF_INDEX}" >&2; (( ++problems )); }

header=$(head -1 "$SHEET")
IFS=, read -r -a cols <<< "$header"
declare -A col_idx
for i in "${!cols[@]}"; do col_idx["${cols[$i]}"]=$i; done

resolve() {
    local p="$1"
    [[ "$p" = /* ]] && echo "$p" || echo "${SHEET_DIR}/${p}"
}

while IFS=, read -r -a fields; do
    [[ "${fields[0]}" == "sample_id" ]] && continue

    id="${fields[${col_idx[sample_id]}]}"
    lib_type="${fields[${col_idx[library_type]}]}"
    r1=$(resolve "${fields[${col_idx[r1_fastq]}]}")
    r2=""
    if [[ "$lib_type" == paired ]]; then
        r2=$(resolve "${fields[${col_idx[r2_fastq]}]:-}")
    fi

    [[ -s "$r1" ]] || { echo "$id: R1 missing or empty: $r1" >&2; (( ++problems )); }

    if [[ "$lib_type" == paired && -n "$r2" ]]; then
        [[ -s "$r2" ]] || { echo "$id: paired but R2 missing: $r2" >&2; (( ++problems )); }
    fi

    if [[ -s "$r1" ]]; then
        gzip -t "$r1" 2>/dev/null || { echo "$id: R1 is not a valid gzip file: $r1" >&2; (( ++problems )); }
    fi
    if [[ "$lib_type" == paired && -n "$r2" && -s "$r2" ]]; then
        gzip -t "$r2" 2>/dev/null || { echo "$id: R2 is not a valid gzip file: $r2" >&2; (( ++problems )); }
    fi
done < "$SHEET"

(( problems == 0 )) || { echo "validation failed with ${problems} problem(s)" >&2; exit 65; }
echo "validation passed" >&2
