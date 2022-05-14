/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowQuaisar.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK         } from '../subworkflows/local/input_check'
include { SPADES_LOCAL        } from '../modules/local/localspades'
include { BUSCO               } from '../modules/local/busco'
include { GAMMA_S             } from '../modules/local/gammas'
include { BBMAP_REFORMAT      } from '../modules/local/bbmapreformat'
include { CONTIG_PREP         } from '../modules/local/contigprep'
include { GAMMA_PREP          } from '../modules/local/gammaprep'
/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BBMAP_BBDUK                       } from '../modules/nf-core/modules/bbmap/bbduk/main'
include { FASTP                             } from '../modules/nf-core/modules/fastp/main'
include { FASTQC as FASTQCTRIMD             } from '../modules/nf-core/modules/fastqc/main'
include { SRST2_SRST2 as SRST2_TRIMD_AR     } from '../modules/nf-core/modules/srst2/srst2/main'
include { SRST2_SRST2 as SRST2_TRIMD_MLST   } from '../modules/nf-core/modules/srst2/srst2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_TRIMD  } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_ASMBLD } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { SPADES                            } from '../modules/nf-core/modules/spades/main'
include { FASTANI                           } from '../modules/nf-core/modules/fastani/main'
include { MLST                              } from '../modules/nf-core/modules/mlst/main'
include { GAMMA as GAMMA_AR                 } from '../modules/nf-core/modules/gamma/main'
include { PROKKA                            } from '../modules/nf-core/modules/prokka/main'
include { QUAST                             } from '../modules/nf-core/modules/quast/main'
include { GAMMA as GAMMA_HV                 } from '../modules/nf-core/modules/gamma/main'
include { MULTIQC                           } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS       } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow QUAISAR {

    ch_versions     =   Channel.empty()
    ch_tree_input   =   Channel.empty()
    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    BBMAP_BBDUK (
        INPUT_CHECK.out.reads, params.bbdukdb
    )
    ch_versions = ch_versions.mix(BBMAP_BBDUK.out.versions)

    FASTP (
        BBMAP_BBDUK.out.reads, true, true
    )
    ch_versions = ch_versions.mix(FASTP.out.versions)

    FASTQCTRIMD (
        FASTP.out.reads
    )
    ch_versions = ch_versions.mix(FASTQCTRIMD.out.versions.first())

    SRST2_TRIMD_AR (
        FASTP.out.reads.map{ meta, reads -> [ [id:meta.id, single_end:meta.single_end, db:'gene'], reads, params.srstar]}
    )
    ch_versions = ch_versions.mix(SRST2_TRIMD_AR.out.versions)


    KRAKEN2_TRIMD (
        FASTP.out.reads, params.path2db, true, true
    )
    ch_versions = ch_versions.mix(KRAKEN2_TRIMD.out.versions)

    SPADES_LOCAL (
        FASTP.out.reads
    )
    ch_versions = ch_versions.mix(SPADES_LOCAL.out.versions)

    BBMAP_REFORMAT (
        SPADES_LOCAL.out.scaffolds
    )
    ch_versions = ch_versions.mix(BBMAP_REFORMAT.out.versions)

    GAMMA_PREP (
        BBMAP_REFORMAT.out.reads
    )

    //FASTANI (
        //BBMAP_REFORMAT.out.reads, params.ardb
    //)
    //ch_versions = ch_versions.mix(FASTANI.out.versions)

    MLST (
        BBMAP_REFORMAT.out.reads
    )
    ch_versions = ch_versions.mix(MLST.out.versions)

    GAMMA_HV (
        GAMMA_PREP.out.prepped, params.hvgamdb
    )
    ch_versions = ch_versions.mix(GAMMA_HV.out.versions)

    GAMMA_AR (
        GAMMA_PREP.out.prepped, params.ardb
    )
    ch_versions = ch_versions.mix(GAMMA_AR.out.versions)

    GAMMA_S (
        GAMMA_PREP.out.prepped, params.gamdbpf
    )
    ch_versions = ch_versions.mix(GAMMA_S.out.versions)

    PROKKA (
        GAMMA_PREP.out.prepped, [], []
    )
    ch_versions = ch_versions.mix(PROKKA.out.versions)

    CONTIG_PREP (
        SPADES_LOCAL.out.contigs
    )

    QUAST (
        CONTIG_PREP.out.contigs, [], [], false, false
    )
    ch_versions = ch_versions.mix(QUAST.out.versions)

    BUSCO (
        BBMAP_REFORMAT.out.reads, 'auto', [], []
    )
    ch_versions = ch_versions.mix(BUSCO.out.versions)


    //error kraken2: --paired requires positive and even number filename updated bbformat to change the numbers of the files
    KRAKEN2_ASMBLD (
        BBMAP_REFORMAT.out.reads, params.path2db, true, true
    )
    //ch_versions = ch_versions.mix(KRAKEN2_ASMBLD.out.versions)

    //CUSTOM_DUMPSOFTWAREVERSIONS (
        //ch_versions.unique().collectFile(name: 'collated_versions.yml')
    //)

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowQuaisar.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    //ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQCTRIMD.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
