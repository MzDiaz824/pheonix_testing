// Check quality of raw reads

include { FASTQC } from '../modules/nf-core/modules/fastqc/main'

workflow TRIM_QC {
    
    FASTQC ( reads )
    
}