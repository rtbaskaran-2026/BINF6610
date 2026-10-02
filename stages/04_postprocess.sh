# stages/04_postprocess.sh
stage_postprocess() {
    local id cond rep lt r1 r2
    while IFS=, read -r id cond rep lt r1 r2; do
        if [[ -s "${ALN}/${id}.dedup.bam" ]]; then log "$id: postprocess already done"; continue; fi

        gatk MarkDuplicates \
            -I "${ALN}/${id}.bam" \
            -O "${ALN}/${id}.dedup.part.bam" \
            -M "${LOG}/${id}.dedup.metrics.txt" \
            2> "${LOG}/${id}.markdup.log"

        [[ -s "${ALN}/${id}.dedup.part.bam" ]] || die "$id: MarkDuplicates produced no BAM"

        mv "${ALN}/${id}.dedup.part.bam" "${ALN}/${id}.dedup.bam"
        samtools index -@ "$SORT_THREADS" "${ALN}/${id}.dedup.bam"

        log "$id: duplicates marked"
    done < <(rows "$SHEET" "$SAMPLE")
}
