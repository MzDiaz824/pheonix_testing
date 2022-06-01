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
def checkPathParamList = [ params.input, params.multiqc_config ] //removed , params.fasta to stop issue w/connecting to aws and igenomes not used
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters

//input on command line
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet/list not specified!' }

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
include { INPUT_CHECK            } from '../subworkflows/local/input_check'
include { SPADES_LOCAL           } from '../modules/local/localspades'
include { BUSCO                  } from '../modules/local/busco'
include { GAMMA_S                } from '../modules/local/gammas'
include { FASTP as FASTP_SINGLES } from '../modules/local/localfastp'
include { BBMAP_REFORMAT         } from '../modules/local/contig_less500'
include { GAMMA_PREP             } from '../modules/local/gammaprep'
include { QUAST                  } from '../modules/local/localquast'
include { FASTANI                } from '../modules/local/localfastani'
//include { GET_REFS               } from '../modules/local/getrefseqgenomes'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BBMAP_BBDUK                       } from '../modules/nf-core/modules/bbmap/bbduk/main'
include { FASTP as FASTP_TRIMD              } from '../modules/nf-core/modules/fastp/main'
include { FASTQC as FASTQCTRIMD             } from '../modules/nf-core/modules/fastqc/main'
include { SRST2_SRST2 as SRST2_TRIMD_AR     } from '../modules/nf-core/modules/srst2/srst2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_TRIMD  } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_ASMBLD } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { MASH_SKETCH                       } from '../modules/nf-core/modules/mash/sketch/main'
include { MASH_DIST                         } from '../modules/nf-core/modules/mash/dist/main'
include { MLST                              } from '../modules/nf-core/modules/mlst/main'
include { GAMMA as GAMMA_AR                 } from '../modules/nf-core/modules/gamma/main'
include { PROKKA                            } from '../modules/nf-core/modules/prokka/main'
include { GAMMA as GAMMA_HV                 } from '../modules/nf-core/modules/gamma/main'
include { MULTIQC                           } from '../modules/nf-core/modules/multiqc/main'
include { KRONA_KRONADB                     } from '../modules/nf-core/modules/krona/kronadb/main'
include { KRONA_KTIMPORTTAXONOMY            } from '../modules/nf-core/modules/krona/ktimporttaxonomy/main'
include { KRONA_KTIMPORTTEXT                } from '../modules/nf-core/modules/krona/ktimporttext/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS       } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow QUAISAR {

    ch_versions     = Channel.empty()
    ch_sra_list     = Channel.empty()
    spades_ch       = Channel.empty()

    if(params.sra_file)
    {
        ch_sra_list = from.SRA(params.sra_file)
    }
    //
    // SUBWORKFLOW: Read in samplesheet/list, validate and stage input files
    //

    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    BBMAP_BBDUK (
        INPUT_CHECK.out.reads, params.bbdukdb
    )
    ch_versions = ch_versions.mix(BBMAP_BBDUK.out.versions)

    FASTP_TRIMD (
        BBMAP_BBDUK.out.reads, true, true
    )
    ch_versions = ch_versions.mix(FASTP_TRIMD.out.versions)

    FASTP_SINGLES (
        FASTP_TRIMD.out.reads_fail, false, false
    )
    ch_versions = ch_versions.mix(FASTP_SINGLES.out.versions)

    FASTQCTRIMD (
        FASTP_TRIMD.out.reads
    )
    ch_versions = ch_versions.mix(FASTQCTRIMD.out.versions.first())

    SRST2_TRIMD_AR (
        FASTP_TRIMD.out.reads.map{ meta, reads -> [ [id:meta.id, single_end:meta.single_end, db:'gene'], reads, params.ardb]}
    )
    ch_versions = ch_versions.mix(SRST2_TRIMD_AR.out.versions)

    KRAKEN2_TRIMD (
        FASTP_TRIMD.out.reads, params.path2db, true, true
    )
    ch_versions = ch_versions.mix(KRAKEN2_TRIMD.out.versions)

    SPADES_LOCAL (
        FASTP_TRIMD.out.reads
    )
    ch_versions = ch_versions.mix(SPADES_LOCAL.out.versions)
    spades_ch = SPADES_LOCAL.out.scaffolds.map{meta, scaffolds -> [ [id:meta.id, single_end:true], scaffolds]}

    BBMAP_REFORMAT (
        spades_ch
    )
    ch_versions = ch_versions.mix(BBMAP_REFORMAT.out.versions)

    GAMMA_PREP (
        BBMAP_REFORMAT.out.reads
    )

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

   QUAST (
        BBMAP_REFORMAT.out.reads
    )
    ch_versions = ch_versions.mix(QUAST.out.versions)

    BUSCO (
        spades_ch, 'auto', [], []
    )
    ch_versions = ch_versions.mix(BUSCO.out.versions)

    KRAKEN2_ASMBLD (
        BBMAP_REFORMAT.out.reads, params.path2db, true, true
    )
    ch_versions = ch_versions.mix(KRAKEN2_ASMBLD.out.versions)

   FASTANI (
        BBMAP_REFORMAT.out.reads, params.refs
    )
    ch_versions = ch_versions.mix(FASTANI.out.versions)

/*
    KRONA_KRONADB ( )
    ch_versions = ch_versions.mix(KRONA_KRONADB.out.versions)

    KRONA_KTIMPORTTAXONOMY (
        KRAKEN2_ASMBLD.out.
    )
    ch_versions = ch_versions.mix(KRONA_KTIMPORTTAXONOMY.out.versions)

    KRONA_KTIMPORTTEXT (
        KRAKEN2_ASMBLD.out.report
    )
    ch_versions = ch_versions.mix(KRONA_KTIMPORTTEXT.out.versions)
*/
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )


    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowQuaisar.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
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
