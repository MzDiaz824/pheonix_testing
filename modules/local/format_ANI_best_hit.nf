process FORMAT_ANI {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(ani_file)

    output:
    tuple val(meta), path('*.fastANI.txt'), emit: ani_best_hit

    script: // This script is bundled with the pipeline, in cdcgov/phoenix/bin/
    """
    ANI_best_hit_formatter.sh -a $ani_file
    """
}
