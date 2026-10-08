// Stage 0 · validate — check everything before computing anything.
process VALIDATE {
    container params.containers.tools

    input:
    path samplesheet
    path reads
    path ref
    path ref_index
    path ref_dict

    output:
    path "${samplesheet}", emit: sheet

    script:
    """
    validate_samplesheet.sh ${samplesheet} "${ref}" "${ref_index}" "${ref_dict}"
    """
}
