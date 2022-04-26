// Check mandatory parameters
if (params.reads) { raw_reads = Channel.fromPath(params.reads) } else { exit 1, 'Please move your FASTQ files to the "FASTQs" folder!' }
include { FASTQC } from '../modules/nf-core/modules/fastp/main'
workflow RAW_READ_QC {
    FASTQC ( raw_reads )
    //MULTIqc??
}