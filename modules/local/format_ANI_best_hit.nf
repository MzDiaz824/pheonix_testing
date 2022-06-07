process FORMAT_ANI {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(ani_file)

    output:
    tuple val(meta), path('*.fastANI.txt'), emit: ani_best_hit

    script:
    """
    ANI_best_hit_formatter.sh -e $ani_file
    """
}
