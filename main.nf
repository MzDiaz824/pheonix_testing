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
//FastQ files must be saved in the FASTQs folder
//params.reads = "./FASTQs/*_R{1,2}.fastq.gz"
//params.bulkFastqBase = "./MiSeqAnalysisFiles/reads2QC/*{R1,R2}_001.fastq"
//params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')
/*=====================================================================================================================================
                                                       Channels   
====================================================================================================================================
*/
/*drag and drop files into supplied folder name FASTQs
those files will be parsed and grouped as pairs
Will need to add logic to support single reads as current s/u supports paired reads only*/
Channel
    .fromFilePairs("$baseDir/FASTQs/*_R{1,2}*.{fastq,fastq.gz,fq,fq.gz}")
    //.ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .set { readPairs }

Channel
    .fromFilePairs( params.bulkFastqBase)
    //.ifEmpty { error "Cannot find any reads matching: ${params.bulkFastqBase}" }
    .set { fqPairs }
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


// WORKFLOW: Run main nf-core/quaisar analysis pipeline
//

workflow NFCORE_QUAISAR {
    QUAISAR ()
}
/*Channel
    .fromFilePairs( params.reads )
    //.ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .set { readPairs }*/
Channel
    .fromPath( params.phiX )
    .set { phiX }
//work on creating channels for dbs needed for processes in workflow
Channel
    .fromPath(params.databases)
    .ifEmpty {exit 1, "There are no databases found: ${params.databases}"}
    .set { dbs } //need to set up for each dbs
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
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//start Workflow if databases exist

    workflow {
        NFCORE_QUAISAR ()
        RAW_READ_QC (readPairs)
    
}



/*
========================================================================================
                                    PROCESSES
========================================================================================
*/
//incase gunzip is problematic
/*process UNZIPFASTQ {
    tag "$name"
    publishDir "$params.outdir/$name/"
	publishDir "$params.outdir/reads2QC/", mode: 'copy'

    input:
    tuple val(name), file(data)

  	output:
    file "*.fastq"

  	script:
	  """
	  gzip -c "${name}_R1_001.fastq.gz"  > "${name}_R1_001.fastq"
	  gzip -c "${name}_R2_001.fastq.gz"  > "${name}_R2_001.fastq"
	  """
 }*/
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
