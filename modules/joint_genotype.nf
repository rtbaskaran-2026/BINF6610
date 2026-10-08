// Stage 6 · merge — joint genotyping across the whole cohort.
process JOINT_GENOTYPE {
    container params.containers.gatk

    input:
    path gvcfs
    path tbis
    path ref
    path ref_index
    path ref_dict
    val region

    output:
    path 'cohort.vcf.gz', emit: vcf
    path 'cohort.vcf.gz.tbi', emit: tbi
    
    script:
    def gvcf_args = gvcfs.collect { "-V ${it}" }.join(' ')
    """
    gatk CombineGVCFs \\
        -R ${ref} \\
        ${gvcf_args} \\
        -O combined.g.vcf.gz

    gatk GenotypeGVCFs \\
        -R ${ref} \\
        -V combined.g.vcf.gz \\
        -O cohort.vcf.gz \\
        -L ${region}
    """
}
