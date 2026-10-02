# stages/05_quantify.sh
stage_quantify() {
    local id cond rep lt r1 r2
    while IFS=, read -r id cond rep lt r1 r2; do
        if [[ -s "${GVCF}/${id}.g.vcf.gz" ]]; then log "$id: quantify already done"; continue; fi

        gatk HaplotypeCaller \
            -R "$REF" \
            -I "${ALN}/${id}.dedup.bam" \
            -O "${GVCF}/${id}.g.vcf.gz.part.gz" \
            -L "$REGION" \
            -ERC GVCF \
            2> "${LOG}/${id}.haplotypecaller.log"

        [[ -s "${GVCF}/${id}.g.vcf.gz.part.gz" ]] || die "$id: HaplotypeCaller produced no GVCF"

        mv "${GVCF}/${id}.g.vcf.gz.part.gz" "${GVCF}/${id}.g.vcf.gz"
        mv "${GVCF}/${id}.g.vcf.gz.part.gz.tbi" "${GVCF}/${id}.g.vcf.gz.tbi"

        log "$id: GVCF made"
    done < <(rows "$SHEET" "$SAMPLE")
}
