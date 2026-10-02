# stages/02_trim.sh
stage_trim() {
    local id cond rep lt r1 r2 n
    while IFS=, read -r id cond rep lt r1 r2; do
        if [[ -s "${TRIM}/${id}_R1.fastq.gz" ]]; then log "$id: trim already done"; continue; fi

        if [[ "$lt" == paired ]]; then
            fastp -w "$THREADS" -i "$r1" -I "$r2" \
                  -o "${TRIM}/${id}_R1.fastq.gz.part.gz" -O "${TRIM}/${id}_R2.fastq.gz.part.gz" \
                  -j "${LOG}/${id}.fastp.json" -h "${LOG}/${id}.fastp.html" \
                  2> "${LOG}/${id}.fastp.log"
        else
            fastp -w "$THREADS" -i "$r1" -o "${TRIM}/${id}_R1.fastq.gz.part.gz" \
                  -j "${LOG}/${id}.fastp.json" -h "${LOG}/${id}.fastp.html" \
                  2> "${LOG}/${id}.fastp.log"
        fi

        n=$(gzip -dc "${TRIM}/${id}_R1.fastq.gz.part.gz" | wc -l)
        (( n > 0 )) || die "$id: nothing survived trimming"

        mv "${TRIM}/${id}_R1.fastq.gz.part.gz" "${TRIM}/${id}_R1.fastq.gz"
        [[ "$lt" == paired ]] && mv "${TRIM}/${id}_R2.fastq.gz.part.gz" "${TRIM}/${id}_R2.fastq.gz"

        log "$id: trimmed to $(( n / 4 )) reads"
    done < <(rows "$SHEET" "$SAMPLE")
}
