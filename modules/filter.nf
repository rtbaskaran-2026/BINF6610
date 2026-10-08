// Stage 7 · analyze — hard-filter the cohort VCF, and summarize it as a table.
process FILTER {
    container params.containers.gatk

    input:
    path vcf
    path ref
    path ref_index
    path ref_dict
    path vcf_tbi

    output:
    path 'cohort.filtered.vcf.gz', emit: vcf
    path 'variants.tsv',           emit: table

    script:
    """
    gatk VariantFiltration \\
        -R ${ref} \\
        -V ${vcf} \\
        -O cohort.filtered.vcf.gz \\
        --filter-expression "QD < 2.0 || QUAL < 30.0 || SOR > 3.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0" \\
        --filter-name "GATK_Standard_SNP_Filter"

    printf 'CHROM\\tPOS\\tREF\\tALT\\tFILTER\\n' > variants.tsv
    bcftools query -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%FILTER\\n' cohort.filtered.vcf.gz >> variants.tsv
    """
}
