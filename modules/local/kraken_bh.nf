process KRAKEN_BEST_HIT {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(kraken_report)

    output:
    tuple val(meta), path('*.summary.txt')

    script: // This script is bundled with the pipeline, in cdcgov/phoenix/bin/
    """
    kraken2_best_hit.sh -i $kraken_report
    """
}
