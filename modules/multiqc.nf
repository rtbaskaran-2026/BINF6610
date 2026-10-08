// Stage 8 · qc_report — MultiQC over every log this run produced.
process MULTIQC {
    container params.containers.multiqc

    input:
    path '*'

    output:
    path 'multiqc_report.html', emit: report

    script:
    """
    multiqc -q -f .
    """
}
