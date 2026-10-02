# stages/06_merge.sh
stage_merge() {
    local id cond rep lt r1 r2
    local gvcf_args=()

    while IFS=, read -r id cond rep lt r1 r2; do
        [[ -s "${GVCF}/${id}.g.vcf.gz" ]] || die "no GVCF for ${id}; stage 5 did not finish for it"
        gvcf_args+=(-V "${GVCF}/${id}.g.vcf.gz")
    done < <(rows "$SHEET")

    gatk CombineGVCFs \
        -R "$REF" \
        "${gvcf_args[@]}" \
        -O "${VCF}/combined_samples.g.vcf.gz.part.gz" \
        2> "${LOG}/gatk_combinegvcfs.log"

    [[ -s "${VCF}/combined_samples.g.vcf.gz.part.gz" ]] || die "CombineGVCFs did not produce anything"
    mv "${VCF}/combined_samples.g.vcf.gz.part.gz" "${VCF}/combined_samples.g.vcf.gz"
    mv "${VCF}/combined_samples.g.vcf.gz.part.gz.tbi" "${VCF}/combined_samples.g.vcf.gz.tbi"

    gatk GenotypeGVCFs \
        -R "$REF" \
        -V "${VCF}/combined_samples.g.vcf.gz" \
        -O "${VCF}/combined_samples.vcf.gz.part.gz" \
        2> "${LOG}/gatk_genotypegvcfs.log"

    [[ -s "${VCF}/combined_samples.vcf.gz.part.gz" ]] || die "GenotypeGVCFs did not produce anything"
    mv "${VCF}/combined_samples.vcf.gz.part.gz" "${VCF}/combined_samples.vcf.gz"
    mv "${VCF}/combined_samples.vcf.gz.part.gz.tbi" "${VCF}/combined_samples.vcf.gz.tbi"

    log "cohort VCF created"
}
