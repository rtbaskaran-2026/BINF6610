nextflow.preview.output = true

// variant-call, your DNA pipeline: the ten stages of weeks 1-3 as Nextflow processes.
include { VALIDATE }         from './modules/validate'
include { FASTQC }           from './modules/fastqc'
include { FASTP }            from './modules/fastp'
include { BWA_MEM }          from './modules/bwa_mem'
include { MARKDUPLICATES }   from './modules/markduplicates'
include { HAPLOTYPECALLER }  from './modules/haplotypecaller'
include { JOINT_GENOTYPE }   from './modules/joint_genotype'
include { FILTER }           from './modules/filter'
include { MULTIQC }          from './modules/multiqc'
include { PUBLISH }          from './modules/publish'

workflow {
    main:
    ref       = file(params.ref)
    ref_index = file("${params.ref}.fai")
    bwa_index = files("${params.ref}.{amb,ann,bwt,pac,sa}")
    ref_dict  = file(params.ref.replaceAll(/\.fa(sta)?$/, '.dict'))
    sheet     = file(params.samplesheet)

    // One item per sample: [meta, reads], with meta = [id: ..., single_end: ...].
    ch_samples = channel.fromPath(sheet)
        .splitCsv(header: true)
        .map { row ->
            def meta = [id: row.sample_id, single_end: row.library_type == 'single']
            def r1 = sheet.parent.resolve(row.r1_fastq)
            def reads = meta.single_end ? [r1] : [r1, sheet.parent.resolve(row.r2_fastq)]
            [meta, reads]
        }

    // Stage 0 checks every FASTQ before anything else starts: each sample waits for it.
    VALIDATE(sheet, ch_samples.map { _meta, reads -> reads }.collect(),
              ref, ref_index, ref_dict)
    ch_checked = ch_samples
        .combine(VALIDATE.out.sheet)
        .map { meta, reads, _validated -> [meta, reads] }

    FASTQC(ch_checked)
    FASTP(ch_checked)
    BWA_MEM(FASTP.out.reads, ref, ref_index, bwa_index)
    MARKDUPLICATES(BWA_MEM.out.bam)
    HAPLOTYPECALLER(MARKDUPLICATES.out.bam, ref, ref_index, ref_dict, params.region)

    JOINT_GENOTYPE(
        HAPLOTYPECALLER.out.gvcf.map { _meta, gvcf -> gvcf }.collect(),
        HAPLOTYPECALLER.out.tbi.map { _meta, tbi -> tbi }.collect(),
        ref, ref_index, ref_dict, params.region
    )
    FILTER(JOINT_GENOTYPE.out.vcf, ref, ref_index, ref_dict, JOINT_GENOTYPE.out.tbi)

    ch_qc = FASTQC.out.zip
        .mix(FASTP.out.json)
        .collect()
    MULTIQC(ch_qc)

    PUBLISH(
        VALIDATE.out.sheet,
        FILTER.out.vcf.mix(FILTER.out.table, MULTIQC.out.report).collect()
    )

    publish:
    vcf      = FILTER.out.vcf
    variants = FILTER.out.table
    multiqc  = MULTIQC.out.report
    manifest = PUBLISH.out.manifest
    samples  = PUBLISH.out.samples
}

output {
    vcf {
        path '.'
    }
    variants {
        path '.'
    }
    multiqc {
        path '.'
    }
    manifest {
        path '.'
    }
    samples {
        path '.'
    }
}
