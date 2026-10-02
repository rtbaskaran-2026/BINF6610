stage_publish() {
    PIPELINE_NAME=dna-variant-call \
        bash "${PIPE_DIR}/lib/write_manifest.sh" "${RES}" "${SHEET}" "${REF}" "${REGION}"

    log "results in ${RES}:"
    ls -1 "$RES" >&2
}
