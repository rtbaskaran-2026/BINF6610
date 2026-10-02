stage_qc_raw() {
    local id cond rep lt r1 r2 base
    while IFS=, read -r id cond rep lt r1 r2; do
        base=$(basename "$r1" .fastq.gz)
        if [[ -s "${QC}/${base}_fastqc.zip" ]]; then log "$id: qc already done"; continue; fi

        # stdout as well as stderr: fastqc prints "application/gzip" per file on
        # STDOUT, which otherwise lands in the job log and looks like output.
        fastqc -q -t "$THREADS" -o "$QC" "$r1" > "${LOG}/${id}.fastqc.log" 2>&1
        [[ "$lt" != paired ]] || fastqc -q -t "$THREADS" -o "$QC" "$r2" >> "${LOG}/${id}.fastqc.log" 2>&1

        # fastqc can exit 0 and write nothing. Ask the disk.
        [[ -s "${QC}/${base}_fastqc.zip" ]] || die "$id: fastqc produced no report"
        log "$id: qc done"
    done < <(rows "$SHEET" "$SAMPLE")
}
