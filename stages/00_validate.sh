# shellcheck shell=bash
set -euo pipefail   # already set by the driver that sources this; stated here so the file says so itself
# 0 · validate — check everything before computing anything.
stage_validate() {
    local id cond rep lt r1 r2 problems=0 before=0 n1 n2 r1_ok r2_ok

    while IFS=, read -r id cond rep lt r1 r2; do
        [[ -n "$id" ]] || { log "a row has no sample_id"; problems=$(( problems + 1 )); continue; }

        if [[ -s "${LOG}/${id}.validated" ]]; then log "$id: inputs already verified"; continue; fi
        before=$problems

        [[ -s "$r1" ]] || { log "$id: R1 missing or empty: $r1"; problems=$(( problems + 1 )); }
        if [[ "$lt" == paired ]]; then
            [[ -s "$r2" ]] || { log "$id: declared paired but R2 is missing"; problems=$(( problems + 1 )); }
        fi

        r1_ok=0 r2_ok=0
        if [[ -s "$r1" ]]; then
            if gzip -t "$r1" 2>/dev/null; then r1_ok=1
            else log "$id: R1 is not a valid gzip file"; problems=$(( problems + 1 )); fi
        fi
        if [[ "$lt" == paired && -s "$r2" ]]; then
            if gzip -t "$r2" 2>/dev/null; then r2_ok=1
            else log "$id: R2 is not a valid gzip file"; problems=$(( problems + 1 )); fi
        fi
        if (( r1_ok )); then
            n1=$(gzip -dc "$r1" | wc -l)
            (( n1 % 4 == 0 )) || { log "$id: R1 has $n1 lines, not a whole number of records"
                                   problems=$(( problems + 1 )); }
            if (( r2_ok )); then
                n2=$(gzip -dc "$r2" | wc -l)
                (( n1 == n2 )) || { log "$id: R1 has $(( n1 / 4 )) reads, R2 has $(( n2 / 4 ))"
                                    problems=$(( problems + 1 )); }
            fi
        fi

        if (( problems == before )); then
            date -u +%Y-%m-%dT%H:%M:%SZ > "${LOG}/${id}.validated"
        fi
    done < <(rows "$SHEET" "$SAMPLE")

    local dupes
    dupes=$(rows "$SHEET" | cut -d, -f1 | sort | uniq -d)
    [[ -z "$dupes" ]] || { log "duplicate sample_id: $dupes"; problems=$(( problems + 1 )); }

    [[ -s "${REF}" ]]      || { log "no reference at ${REF}";          problems=$(( problems + 1 )); }
    [[ -s "${REF}.fai" ]]  || { log "no .fai index at ${REF}.fai";      problems=$(( problems + 1 )); }
    [[ -s "${REF}.bwt" ]]  || { log "no BWA index at ${REF}.bwt";       problems=$(( problems + 1 )); }

    (( problems == 0 )) || die "validation failed with ${problems} problem(s)"
    log "validation passed"
}
