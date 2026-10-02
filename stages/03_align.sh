# shellcheck shell=bash
set -euo pipefail   # already set by the driver that sources this; stated here so the file says so itself
# 3 · align — BWA-MEM straight into a sorted BAM.
stage_align() {
    local id cond rep lt r1 r2 sort_tmp
    while IFS=, read -r id cond rep lt r1 r2; do
        if [[ -s "${ALN}/${id}.bam" ]]; then log "$id: align already done"; continue; fi

        sort_tmp="${TMPDIR:-/tmp}/sort.${id}.$$"

        if [[ "$lt" == paired ]]; then
            bwa mem -t "$ALIGN_THREADS" -R "@RG\tID:${id}\tSM:${id}" "$REF" \
                "${TRIM}/${id}_R1.fastq.gz" "${TRIM}/${id}_R2.fastq.gz" \
                2> "${LOG}/${id}.bwa.log"
        else
            bwa mem -t "$ALIGN_THREADS" -R "@RG\tID:${id}\tSM:${id}" "$REF" \
                "${TRIM}/${id}_R1.fastq.gz" \
                2> "${LOG}/${id}.bwa.log"
        fi | samtools sort -@ "$SORT_THREADS" -T "$sort_tmp" -o "${ALN}/${id}.part.bam"

        [[ -s "${ALN}/${id}.part.bam" ]] || die "$id: bwa produced no BAM"

        mv "${ALN}/${id}.part.bam" "${ALN}/${id}.bam"
        samtools index -@ "$SORT_THREADS" "${ALN}/${id}.bam"

        log "$id: aligned"
    done < <(rows "$SHEET" "$SAMPLE")
}
