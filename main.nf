#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/quaisar
========================================================================================
    Github : https://github.com/nf-core/quaisar
    Website: https://nf-co.re/quaisar
    Slack  : https://nfcore.slack.com/channels/quaisar
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    DEFINE VALUES THAT CAN BE OVERWRITTEN
========================================================================================
*/

//params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { QUAISAR } from '../workflows/quaisar'
include { RAW_READ_QC } from '../subworkflows/local/rawQC'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

//
// WORKFLOW: Default entry point
// See: https://github.com/nf-core/rnaseq/issues/619
//start Workflow if databases exist

    workflow {
        QUAISAR ( input )
    
}


workflow.onComplete {

   println ( workflow.success ? """
       Pipeline execution summary
       ---------------------------
       Completed at: ${workflow.complete}
       Duration    : ${workflow.duration}
       Success     : ${workflow.success}
       workDir     : ${workflow.workDir}
       Exit status : ${workflow.exitStatus}
       """ : """
       Failed: ${workflow.errorReport}
       Exit status : ${workflow.exitStatus}
       """
   )
}
