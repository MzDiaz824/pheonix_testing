process KRAKEN_BEST_HIT {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(kraken_report)

    output:
    tuple val(meta), path('*.summary.txt')

    script:
    """
    kraken2_best_hit.sh -i $kraken_report
    """
}
