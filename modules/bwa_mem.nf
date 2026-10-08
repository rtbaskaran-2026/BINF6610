// Stage 3 · align — BWA-MEM straight into a sorted, indexed BAM.
process BWA_MEM {
    tag "${meta.id}"
    container params.containers.bwa

    input:
    tuple val(meta), path(reads)
    path ref
    path ref_index
    path bwa_index

    output:
    tuple val(meta), path("${meta.id}.bam"), path("${meta.id}.bam.bai"), emit: bam

    script:
    def align_cpus = task.cpus > 2 ? task.cpus - 2 : 1
    if (meta.single_end) {
        """
        bwa mem -t ${align_cpus} -R "@RG\\tID:${meta.id}\\tSM:${meta.id}" ${ref} ${reads[0]} \\
            | samtools sort -@ 2 -o ${meta.id}.bam
        samtools index ${meta.id}.bam
        """
    } else {
        """
        bwa mem -t ${align_cpus} -R "@RG\\tID:${meta.id}\\tSM:${meta.id}" ${ref} ${reads[0]} ${reads[1]} \\
            | samtools sort -@ 2 -o ${meta.id}.bam
        samtools index ${meta.id}.bam
        """
    }
}
