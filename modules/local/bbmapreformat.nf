process BBMAP_REFORMAT {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bbmap=38.90" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bbmap:38.90--he522d1c_1' :
        'quay.io/biocontainers/bbmap:38.90--he522d1c_1' }"

    input:
    tuple val(meta), path(reads)


    output:
    tuple val(meta), path('*.scaffolds.fa.gz')   , emit: reads
    tuple val(meta), path('*.log')     , emit: log
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def raw      = meta.single_end ? "in=${reads[0]}" : "in1=${reads[0]} in2=${reads[1]}"
    def trimmed  = meta.single_end ? "out=${prefix}.scaffolds.fa.gz" : "out1=${prefix}_2.scaffolds.fa.gz out2=${prefix}_4.scaffolds.fa.gz"
    def minlength = params.minlength
    """
    reformat.sh \\
        $raw \\
        $trimmed \\
        threads=$task.cpus \\
        $args \\
        minlength=$minlength \\
        &> ${prefix}.reformat.log


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$(bbversion.sh)
    END_VERSIONS
    """
}
