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


// WORKFLOW: Run assembled files only
//

workflow NFCORE_QUAISAR {
    
}

//work on creating channels for dbs needed for processes in workflow
/*Channel
    .fromPath(params.databases)
    .ifEmpty {exit 1, "There are no databases found: ${params.databases}"}
    .set { dbs } //need to set up for each dbs*/
//This means channel values are consumed serially one after another and the 
//first empty channel cause the process execution to stop even if there are 
//other values in other channels.
/*if ( params.bbmap_adapters ){
    bbmap_adapters = file("${params.bbmap_adapters}")
}*/
/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Default entry point
// See: https://github.com/nf-core/rnaseq/issues/619
//start Workflow if databases exist

    workflow {
        QUAISAR ()
    
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
