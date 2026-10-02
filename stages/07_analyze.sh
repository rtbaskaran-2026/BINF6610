# stages/07_analyze.sh
stage_analyze() {
    if [[ -s "${VCF}/cohort.filtered.vcf.gz" ]]; then log "analyze already done"; return; fi

    gatk VariantFiltration \
        -R "$REF" \
        -V "${VCF}/combined_samples.vcf.gz" \
        -O "${VCF}/cohort.filtered.vcf.gz.part.gz" \
        --filter-expression "QD < 2.0 || QUAL < 30.0 || SOR > 3.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0" \
        --filter-name "GATK_Standard_SNP_Filter" \
        2> "${LOG}/gatk_variantfiltration.log"

    [[ -s "${VCF}/cohort.filtered.vcf.gz.part.gz" ]] || die "no filtered vcf output"
    mv "${VCF}/cohort.filtered.vcf.gz.part.gz" "${VCF}/cohort.filtered.vcf.gz"
    mv "${VCF}/cohort.filtered.vcf.gz.part.gz.tbi" "${VCF}/cohort.filtered.vcf.gz.tbi"

    log "combined VCF filtered"
}
