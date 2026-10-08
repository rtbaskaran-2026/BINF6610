// Stage 5 · quantify — per-sample variant calling into a GVCF.
process HAPLOTYPECALLER {
    tag "${meta.id}"
    container params.containers.gatk

    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_index
    path ref_dict
    val region

    output:
    tuple val(meta), path("${meta.id}.g.vcf.gz"),     emit: gvcf
    tuple val(meta), path("${meta.id}.g.vcf.gz.tbi"), emit: tbi

    script:
    """
    gatk HaplotypeCaller \\
        -R ${ref} \\
        -I ${bam} \\
        -O ${meta.id}.g.vcf.gz \\
        -L ${region} \\
        -ERC GVCF \\
        --native-pair-hmm-threads ${task.cpus}
    """
}
