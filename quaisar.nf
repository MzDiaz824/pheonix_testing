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
include { INPUT_CHECK } from '../subworkflows/local/input_check'
include { SPADES_LOCAL } from '../modules/local/localspades'
include { SRST2_PREP } from '../modules/local/srst2prep'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BBMAP_BBDUK                 } from '../modules/nf-core/modules/bbmap/bbduk/main'
include { FASTP                       } from '../modules/nf-core/modules/fastp/main'
include { FASTQC as FASTQCTRIMD       } from '../modules/nf-core/modules/fastqc/main'
include { SRST2_SRST2 as SRST2_TRIMD  } from '../modules/nf-core/modules/srst2/srst2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_TRIMD  } from '../modules/nf-core/modules/kraken2/kraken2/main'
include { SPADES                      } from '../modules/nf-core/modules/spades/main'
include { QUAST                       } from '../modules/nf-core/modules/quast/main'
include { FASTANI                     } from '../modules/nf-core/modules/fastani/main'
include { MLST                        } from '../modules/nf-core/modules/mlst/main'
include { PROKKA                      } from '../modules/nf-core/modules/prokka/main'
include { GAMMA as GAMMA_REPL         } from '../modules/nf-core/modules/gamma/main'
include { MULTIQC                     } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow QUAISAR {

    ch_versions = Channel.empty()

    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    BBMAP_BBDUK (
        INPUT_CHECK.out.reads, './bin/databases/phiX.fasta'
    )
    ch_versions = ch_versions.mix(BBMAP_BBDUK.out.versions)

    FASTP (
        BBMAP_BBDUK.out.reads, true, true
    )
    ch_versions = ch_versions.mix(FASTP.out.versions)

    SRST2_PREP (
        FASTP.out.reads
    )

    FASTQCTRIMD (
        FASTP.out.reads
    )

    ch_versions = ch_versions.mix(FASTQCTRIMD.out.versions.first())

    //KRAKEN2_TRIMD (
        //FASTP.out.reads, './bin/databases', true, true
    //)

    //ch_test  =  FASTP.out.reads.map{
                //meta, meta1 ->
                //def fmeta = [:]
                //set meta.id
                //fmeta.id = meta.id
                //set single_end
                //fmeta.single_end = meta.single_end
                //set meta.db
                //fmeta.db = "gene"
                //[fmeta, meta1, './bin/databases/ResGANNCBI_20210507_srst2.fasta']//, FASTP.out.reads, '/scicomp/home-pure/lex0/Documents/nf-core-quaisar/bin/databases/ResGANNCBI_20210507_srst2.fasta']
            //}
            //.view()

    //SRST2_TRIMD (
        //SRST2_PREP.out.reads.map{ meta, reads -> [meta, reads, './bin/databases'] }
    //) //throws error due to change in file format post trim changed module for FASTP to stop adding trim to EOF and now adds to beginning no success
    //ch_versions = ch_versions.mix(SRST2_TRIMD.out.versions)

    SPADES_LOCAL (
        FASTP.out.reads
    )
    ch_versions = ch_versions.mix(SPADES_LOCAL.out.versions)

    //prokka_map = prokka_map.map{SPADES.out.scaffolds, }
    //if (!params.proteins)
    PROKKA (
        SPADES_LOCAL.out.scaffolds, [], []
    )
    ch_versions = ch_versions.mix(PROKKA.out.versions)

    //QUAST (
        //SPADES_LOCAL.out.scaffolds, SPADES.out.contigs, false, PROKKA.out.gff, false
    //)
    //ch_versions = ch_versions.mix(QUAST.out.versions)//doesn't use GFF

    //FASTANI (
        //SPADES_LOCAL.out.scaffolds, params.ani_db
    //)
    ////ch_versions = ch_versions.mix(FASTANI.out.versions)

    MLST (
        SPADES_LOCAL.out.contigs
    )

    ch_versions = ch_versions.mix(SPADES_LOCAL.out.versions)

    /*GAMMA_REPL (
        SPADES.out.scaffolds, './bin/databases/PF-Replicons_20220414.fasta'
    )
    ch_versions = ch_versions.mix(GAMMA_REPL.out.versions)*/


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
