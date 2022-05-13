process GAMMA_PREP {
    tag "$meta.id"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*.scaffolds.fa'), optional:true, emit: prepped
    path('*.scaffolds.fa.gz'), optional:true, emit: scaffolds_quast

    script:
    """
    gunzip -f *.scaffolds.fa.gz
    """
}
