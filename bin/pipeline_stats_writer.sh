#!/bin/sh -l

#$ -o pipestats_writer.out
#$ -e pipestats_writer.err
#$ -N pipestats_writer
#$ -cwd
#$ -q short.q

#
# Description: Checking to see if all standard reported sections of a sample have completed successfully
#
# Usage: ./pipeline_stats_writer.sh -n sample_name -p miseq_run_id [-c path_to_config_file] [-g csstar gapping] [-s csstar similarity] [-l csstar plasmid similarity] [-e explicit_path_to_isolate_folder]
#
# Output location: default_config.sh_output_location/run_ID/1/
#
# Modules required: None
#
# v1.2.5 (04/14/2022)
#
# Created by Nick Vlachos (nvx4@cdc.gov)
#

 #  Function to print out help blurb
 show_help () {
 	echo "Usage: -n sample_name -p run_id [-c path_to_config_file] [-g csstar gapping] [-s csstar similarity] [-l csstar plasmid similarity] [-e explicit_path_to_isolate_folder]"
 }

 # Parse command line options
 options_found=0
 while getopts ":h?c:p:n:g:s:l:e:" option; do
 	options_found=$(( options_found + 1 ))
 	case "${option}" in
 		\?)
 			echo "Invalid option found: ${OPTARG}"
       show_help
       exit 0
       ;;
 		p)
 			#echo "Option -p triggered, argument = ${OPTARG}"
 			project=${OPTARG};;
 		n)
 			#echo "Option -n triggered, argument = ${OPTARG}"
 			sample_name=${OPTARG};;
 		c)
 			#echo "Option -c triggered, argument = ${OPTARG}"
 			config=${OPTARG};;
 		g)
 			#echo "Option -g triggered, argument = ${OPTARG}"
 			gapping=${OPTARG,,};;
 		s)
 			#echo "Option -s triggered, argument = ${OPTARG}"
 			sim=${OPTARG};;
 		l)
 			#echo "Option -s triggered, argument = ${OPTARG}"
 			plasmid_sim=${OPTARG};;
    e)
  		#echo "Option -e triggered, argument = ${OPTARG}"
  		epath=${OPTARG};;
 		:)
 			echo "Option -${OPTARG} requires as argument";;
 		h)
 			show_help
 			exit 0
 			;;
 	esac
 done

 if [[ "${options_found}" -eq 0 ]]; then
 	echo "No options found"
 	show_help
 	exit
 fi

 if [[ -f "${config}" ]]; then
 	#echo "Loading special config file - ${config}"
 	. "${config}"
 else
 	#echo "Loading default config file"
 	if [[ ! -f "./config.sh" ]]; then
 		cp ./config_template.sh ./config.sh
 	fi
 	. ./config.sh
 	cwd=$(pwd)
 	config="${cwd}/config.sh"
 fi

 # Checks for proper argumentation
 # Checks for correct parameter s and sets appropriate outdatadirs
 if [[ ! -z "${epath}" ]]; then
 	if [[ ! -z "${project}" ]] || [[ ! -z "${sample_name}" ]]; then
 		echo "Cant set explicit path AND project or sample name, omit one of the params and rsubmit, exiting"
 		exit 454
 	fi
  if [[ "${epath: -1}" == "/" ]]; then
		epath=${epath::-1}
	fi
 	OUTDATADIR="${epath}"
 	project=$(echo "${epath}" | rev | cut -d'/' -f2 | rev)
 	sample_name=$(echo "${epath}" | rev | cut -d'/' -f1 | rev)
 else
 	if [[ -z "${sample_name}" ]]; then
 		echo "Empty sample name supplied to run_kraken.sh, exiting"
 		exit 1
 	elif [ -z "${project}" ]; then
 		echo "Empty project name given. Exiting"
 		exit 1
 	fi
 	OUTDATADIR="${processed}/${project}/${sample_name}"
 fi

 if [[ ! -z "${gapping}" ]] && [[ "${gapping}" != "gapped" ]] && [[ "${gapping}" != "ungapped" ]]; then
 	echo "Incorrect gapping provided to pipeline_stats_writer.sh, exiting"
 	exit 37
 elif [[ ! -z "${sim}" ]] && [[ "${sim}" -ge 80 ]] && [[ "${sim}" -le 100 ]]; then
 	echo "Similarity must be between 80 and 100%, exiting"
 	exit 38
 fi

 char="_"
 sample_name_underscore_count=0
 sample_name_underscore_count=$(echo "${sample_name}" | awk -F"${char}" '{print NF-1}')

 run_type="all"

 # Creates and prints header info for the sample being processed
 today=$(date)
 echo "----------Checking ${project}/${sample_name} for successful completion on ----------"  > "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 echo "Sample output folder starts at: " "${OUTDATADIR}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 status="SUCCESS"
 # Checks to see if the sample has a time summary file associated with it
 if [[ -s "${OUTDATADIR}/time_summary.txt" ]]; then
 	mv "${OUTDATADIR}/time_summary.txt" "${OUTDATADIR}/${sample_name}_time_summary.txt"
 fi
 printf "%-20s: %-8s : %s\\n" "Summarized" "SUCCESS" "${today}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 if [[ -s "${OUTDATADIR}/${sample_name}_time_summary.txt" ]]; then
 	time=$(tail -1 "${OUTDATADIR}/${sample_name}_time_summary.txt" | cut -d' ' -f3)
 	printf "%-20s: %-8s : %s\\n" "Time" "SUCCESS" "${time} seconds"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 else
 	printf "%-20s: %-8s : %s\\n" "Time" "ALERT" "No time summary file found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="ALERT"
 fi
 #Checking existence of FASTQ files
 raw_length_R1=-3
 raw_length_R2=-3
 if [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq" ]] && [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq" ]]; then
 	raw_length_R1=$(cat ${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	raw_length_R2=$(cat ${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	if [[ "${raw_length_R1}" -gt 0 ]] && [[ "${raw_length_R2}" -gt 0 ]]; then
 		printf "%-20s: %-8s : %s\\n" "FASTQs" "SUCCESS" "Unzipped - R1: ${raw_length_R1}bps R2: ${raw_length_R2}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	else
 		if [[ "${raw_length_R1}" -le 0 ]]; then
 			printf "%-20s: %-8s : %s\\n" "FASTQs R1" "FAILED" "Unzipped - File has no contents"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "FASTQs R1" "SUCCESS" "Unzipped - ${raw_length_R1}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 		if [[ "${raw_length_R2}" -le 0 ]]; then
 			printf "%-20s: %-8s : %s\\n" "FASTQs R2" "FAILED" "Unzipped - File has no contents"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "FASTQs R2" "SUCCESS" "Unzipped - ${raw_length_R2}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	fi
 elif [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq" ]]; then
 	raw_length_R1=$(cat ${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	if [[ "${raw_length_R1}" -le 0 ]]; then
 		printf "%-20s: %-8s : %s\\n" "FASTQs R1" "FAILED" "Unzipped - File has no base pairs"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	else
 		printf "%-20s: %-8s : %s\\n" "FASTQs R1" "WARNING" "Only R1 found, Unzipped: ${raw_length_R1}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 			status="WARNING"
 		fi
 	fi
 elif [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq" ]]; then
 	raw_length_R2=$(cat ${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	if [[ "${raw_length_R2}" -le 0 ]]; then
 		printf "%-20s: %-8s : %s\\n" "FASTQs R2" "FAILED" "Unzipped - File has no base pairs"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	else
 		printf "%-20s: %-8s : %s\\n" "FASTQs R2" "WARNING" "Only R2 found, Unzipped: ${raw_length_R2}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 			status="WARNING"
 		fi
 	fi
 elif [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq.gz" ]] && [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq.gz" ]]; then
 	raw_length_R1=$(zcat ${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq.gz | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	raw_length_R2=$(zcat ${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq.gz | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	printf "%-20s: %-8s : %s\\n" "FASTQs" "SUCCESS" "Zipped - R1: ${raw_length_R1}bps R2: ${raw_length_R2}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 elif [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq" ]]; then
 	raw_length_R1=$(zcat ${OUTDATADIR}/FASTQs/${sample_name}_R1_001.fastq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	if [[ "${raw_length_R1}" -le 0 ]]; then
 		printf "%-20s: %-8s : %s\\n" "FASTQs R1" "FAILED" "Zipped - File has no contents"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	else
 		printf "%-20s: %-8s : %s\\n" "FASTQs R1" "WARNING" "Only R1 found, Zipped: ${raw_length_R1}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 			status="WARNING"
 		fi
 	fi
 elif [[ -s "${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq" ]]; then
 	raw_length_R2=$(zcat ${OUTDATADIR}/FASTQs/${sample_name}_R2_001.fastq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 	if [[ "${raw_length_R2}" -le 0 ]]; then
 		printf "%-20s: %-8s : %s\\n" "FASTQs R2" "FAILED" "Zipped - File has no contents"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	else
 		printf "%-20s: %-8s : %s\\n" "FASTQs R2" "WARNING" "Only R2 found, Zipped: ${raw_length_R2}bps"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 			status="WARNING"
 		fi
 	fi
elif ([[ -s "${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq" ]] && [[ -s "${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq" ]]) || ([[ -s "${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq.gz" ]] && [[ -s "${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq.gz" ]]); then
 printf "%-20s: %-8s : %s\\n" "FASTQs" "FAILED" "RAW FASTQs Missing"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
elif [[ -s "${OUTDATADIR}/Assembly/${sample_name}_scaffolds_trimmed.fasta" ]]; then
  run_type="assembly-only"
  printf "%-20s: %-8s : %s\\n" "FASTQs" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 elif [[ -s "${OUTDATADIR}/Assembly/${sample_name}_scaffolds_trimmed.fasta" ]]; then
 	run_type="assembly-only"
 	printf "%-20s: %-8s : %s\\n" "FASTQs" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 else
 	printf "%-20s: %-8s : %s\\n" "FASTQs" "FAILED" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 if [[ "${run_type}" == "all" ]]; then
 	#Checking QC counts
 	if [[ -s "${OUTDATADIR}/preQCcounts/${sample_name}_counts.txt" ]]; then
 		reads_pre=$(tail -n1 "${OUTDATADIR}/preQCcounts/${sample_name}_counts.txt" | cut -d'	' -f13)
 		pairs_pre=$((reads_pre/2))
 		Q30_R1=$(tail -n1 "${OUTDATADIR}/preQCcounts/${sample_name}_counts.txt" | cut -d'	' -f10)
 		Q30_R1_rounded=$(echo "${Q30_R1}"  | cut -d'.' -f2)
 		Q30_R1_rounded=$(echo "${Q30_R1_rounded::2}")
 		Q30_R2=$(tail -n1 "${OUTDATADIR}/preQCcounts/${sample_name}_counts.txt" | cut -d'	' -f11)
 		Q30_R2_rounded=$(echo "${Q30_R2}"  | cut -d'.' -f2)
 		Q30_R2_rounded=$(echo "${Q30_R2_rounded::2}")
 		if [[ "${reads_pre}" -le 1000000 ]]; then
 			printf "%-20s: %-8s : %s\\n" "Raw_read_counts" "WARNING" "Low individual read count before trimming: ${reads_pre} (${pairs_pre} paired reads)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="WARNING"
 		elif [[ "${reads_pre}" -le 1000000 ]]; then
 			printf "%-20s: %-8s : %s\\n" "Raw_read_counts" "FAILED" "No individual read count before trimming: ${reads_pre} (${pairs_pre} paired reads)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "Raw_read_counts" "SUCCESS" "${reads_pre} individual reads found in sample (${pairs_pre} paired reads)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 		if [[ "${Q30_R1_rounded}" -lt 90 ]]; then
 			printf "%-20s: %-8s : %s\\n" "Q30_R1%" "WARNING" "Q30_R1% at ${Q30_R1_rounded}% (Threshold is 90%)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
 				status="WARNING"
 			fi
 		else
 			printf "%-20s: %-8s : %s\\n" "Q30_R1%" "SUCCESS" "Q30_R1% at ${Q30_R1_rounded}% (Threshold is 90)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 		if [[ "${Q30_R2_rounded}" -lt 70 ]]; then
 			printf "%-20s: %-8s : %s\\n" "Q30_R2%" "WARNING" "Q30_R2% at ${Q30_R2_rounded}% (Threshold is 70)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
 				status="WARNING"
 			fi
 		else
 			printf "%-20s: %-8s : %s\\n" "Q30_R2%" "SUCCESS" "Q30_R2% at ${Q30_R2_rounded}% (Threshold is 70)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "QC counts" "FAILED" "/preQCcounts/${sample_name}_counts.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		printf "%-20s: %-8s : %s\\n" "Q30_R1%" "FAILED" "/preQCcounts/${sample_name}_counts.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		printf "%-20s: %-8s : %s\\n" "Q30_R2%" "FAILED" "/preQCcounts/${sample_name}_counts.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	# Checking BBDUK output folder
 	if [[ -d "${OUTDATADIR}/removedAdapters" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX" "SUCCESS" "Found"
 		nophi_length_R1=-2
 		nophi_length_R2=-2
 		if [[ -f "${OUTDATADIR}/removedAdapters/no_PhiX_total_lengths.txt" ]]; then
 			nophi_length_R1=$(head -n1 "${OUTDATADIR}/removedAdapters/no_PhiX_total_lengths.txt" | cut -d'	' -f2 )
 			nophi_length_R2=$(tail -n1 "${OUTDATADIR}/removedAdapters/no_PhiX_total_lengths.txt" | cut -d'	' -f2 )
 			R1_diff=$(( raw_length_R1 - nophi_length_R1 ))
 			R2_diff=$(( raw_length_R2 - nophi_length_R2 ))
 			if [[ "${nophi_length_R1}" -lt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R1" "WARNING" "No R1 size found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 					status="WARNING"
 				fi
 			elif [[ "${R1_diff}" -eq 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R1" "ALERT" "R1: No PhiX bases removed (already done on machine etc?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "${status}" = "SUCCESS" ]; then
 					status="ALERT"
 				fi
 			elif [[ "${R1_diff}" -lt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R1" "FAILED" "R1: More phiX-less bps found than raw FASTQ?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			else
 				R1_percent_loss=$(( R1_diff * 100 / ${raw_length_R1} ))
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R1" "SUCCESS" "R1: ${nophi_length_R1} (${R1_percent_loss}% removed)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 			if [[ "${nophi_length_R2}" -lt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R2" "WARNING" "No R2 size found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 					status="WARNING"
 				fi
 			elif [[ "${R2_diff}" -eq 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R2" "ALERT" "R2: No PhiX bases removed (already done on machine etc?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "${status}" = "SUCCESS" ]; then
 					status="ALERT"
 				fi
 			elif [[ "${R2_diff}" -lt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R2" "FAILED" "R2: More phiX-less bps found than raw FASTQ?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			else
 				R2_percent_loss=$(( R2_diff * 100 / ${raw_length_R2} ))
 				printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX-R2" "SUCCESS" "R2: ${nophi_length_R2} (${R2_percent_loss}% removed)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		else
 			printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX" "WARNING" "No total lengths found...did it run?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 				status="WARNING"
 			fi
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX" "#FAILED" "/removedAdapters does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		#status="FAILED"
 	fi

 	#Checking fastP output folder
 	remAdapt_length_R1=-1
 	if [[ -s "${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq" ]]; then
 		remAdapt_length_R1=$(cat ${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 		remAdapt_R1_diff=$(( nophi_length_R1 - remAdapt_length_R1 ))
 		if [[ ${nophi_length_R1} -gt 0 ]]; then
 			if [[ "${remAdapt_length_R1}" -gt 0 ]]; then
 				R1_adapt_percent_loss=$(( remAdapt_R1_diff * 100 / ${nophi_length_R1} ))
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "ALERT" "Unzipped - R1: ${remAdapt_length_R1}bps (${R1_adapt_percent_loss}% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "WARNING" "Unzipped trimmed R1 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		else
 			if [[ "${remAdapt_length_R1}" -gt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "ALERT" "BBDUK R1 counts not created. Unzipped - R1: ${remAdapt_length_R1}bps (UNK% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]]; then
 					status="ALERT"
 				fi
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "WARNING" "BBDUK R1 counts not created. Unzipped trimmed R1 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		fi
 	elif [[ -s "${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq.gz" ]]; then
 		remAdapt_length_R1=$(zcat ${OUTDATADIR}/trimmed/${sample_name}_R1_001.paired.fq.gz | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 		remAdapt_R1_diff=$(( nophi_length_R1 - remAdapt_length_R1 ))
 		if [[ ${nophi_length_R1} -gt 0 ]]; then
 			if [[ "${remAdapt_length_R1}" -gt 0 ]]; then
 				R1_adapt_percent_loss=$(( remAdapt_R1_diff * 100 / ${nophi_length_R1} ))
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "SUCCESS" "Zipped - R1: ${remAdapt_length_R1}bps (${R1_adapt_percent_loss}% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "WARNING" "Zipped trimmed R1 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		else
 			if [[ "${remAdapt_length_R1}" -gt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "ALERT" "BBDUK R1 counts not created. Zipped - R1: ${remAdapt_length_R1}bps (UNK% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]]; then
 					status="ALERT"
 				fi
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R1" "WARNING" "BBDUK R1 counts not created. Zipped trimmed R1 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "Trimming-R1" "FAILED" "No R1 FASTQ file found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	fi
 	remAdapt_length_R2=-1
 	if [[ -s "${OUTDATADIR}/trimmed/${sample_name}_R2_001.paired.fq" ]]; then
 		remAdapt_length_R2=$(cat ${OUTDATADIR}/trimmed/${sample_name}_R2_001.paired.fq | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 		remAdapt_R2_diff=$(( nophi_length_R2 - remAdapt_length_R2 ))
 		if [[ ${nophi_length_R2} -gt 0 ]]; then
 			if [[ "${remAdapt_length_R2}" -gt 0 ]]; then
 				R2_adapt_percent_loss=$(( remAdapt_R2_diff * 100 / ${nophi_length_R2} ))
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "ALERT" "Unzipped - R2: ${remAdapt_length_R2}bps (${R2_adapt_percent_loss}% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "WARNING" "Unzipped trimmed R2 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		else
 			if [[ "${remAdapt_length_R2}" -gt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "ALERT" "BBDUK R2 counts not created. Unzipped - R2: ${remAdapt_length_R2}bps (UNK% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]]; then
 					status="ALERT"
 				fi
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "WARNING" "BBDUK R2 counts not created. Unzipped trimmed R2 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		fi
 	elif [[ -s "${OUTDATADIR}/trimmed/${sample_name}_R2_001.paired.fq.gz" ]]; then
 		remAdapt_length_R2=$(zcat ${OUTDATADIR}/trimmed/${sample_name}_R2_001.paired.fq.gz | paste - - - - | cut -f2 |tr -d '\n' | wc -c)
 		remAdapt_R2_diff=$(( nophi_length_R2 - remAdapt_length_R2 ))
 		if [[ ${nophi_length_R2} -gt 0 ]]; then
 			if [[ "${remAdapt_length_R2}" -gt 0 ]]; then
 				R2_adapt_percent_loss=$(( remAdapt_R2_diff * 100 / ${nophi_length_R2} ))
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "SUCCESS" "Zipped - R2: ${remAdapt_length_R2}bps (${R2_adapt_percent_loss}% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "WARNING" "Zipped trimmed R2 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		else
 			if [[ "${remAdapt_length_R2}" -gt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "ALERT" "BBDUK R2 counts not created. Zipped - R2: ${remAdapt_length_R2}bps (UNK% loss)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]]; then
 					status="ALERT"
 				fi
 			else
 				printf "%-20s: %-8s : %s\\n" "Trimming-R2" "WARNING" "BBDUK R2 counts not created. Zipped trimmed R2 FASTQ has no bases"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "SUCCESS" ]]; then
 					status="WARNING"
 				fi
 			fi
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "Trimming-R2" "FAILED" "No R2 FASTQ file found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	fi

 	#Checking QC counts after trimming
 	if [[ -s "${OUTDATADIR}/preQCcounts/${sample_name}_trimmed_counts.txt" ]]; then
 		reads_post=$(tail -n1 "${OUTDATADIR}/preQCcounts/${sample_name}_trimmed_counts.txt" | cut -d'	' -f13)
 		pairs_post=$((reads_post/2))
 		loss=$(echo "scale=2; 100*(${reads_pre} - ${reads_post}) / ${reads_pre}" | bc )
 		if [[ "${reads_post}" -le 500000 ]]; then
 			printf "%-20s: %-8s : %s\\n" "QC count after trim" "WARNING" "Low individual read count after trimming: ${reads_post} (${pairs_post} paired reads)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="WARNING"
 		else
 			printf "%-20s: %-8s : %s\\n" "QC count after trim" "SUCCESS" "${reads_post} individual reads (${pairs_post} paired reads) after trim. ${loss}% loss"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "QC count after trim" "FAILED" "/preQCcounts/${sample_name}_trimmed_counts.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi


 	#Check kraken on preAssembly
 	kraken_pre_success=false
 	if [[ -s "${OUTDATADIR}/kraken/preAssembly/${sample_name}_paired.kraken" ]] || [[ -s "${OUTDATADIR}/kraken/preAssembly/${sample_name}_paired.kraken.gz" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "kraken preassembly" "SUCCESS" "Found"
 		kraken_pre_success=true
 	else
 		printf "%-20s: %-8s : %s\\n" "kraken preassembly" "FAILED" "/kraken/preAssembly/${sample_name}_paired.kraken not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	#Check Krona output
 	if [[ "${kraken_pre_success}" = true ]]; then
 		if [[ -s "${OUTDATADIR}/kraken/preAssembly/${sample_name}_paired.krona" ]] && [[ -s "${OUTDATADIR}/kraken/preAssembly/${sample_name}_paired.html" ]]; then
 			#printf "%-20s: %-8s : %s\\n" "krona-kraken-preasm" "SUCCESS" "Found"
 			:
 		else
 			printf "%-20s: %-8s : %s\\n" "krona-kraken-preasm" "FAILED" "/kraken/preAssembly/${sample_name}_paired.krona &&|| /kraken/preAssembly/${sample_name}_paired.html not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "krona-kraken-preasm" "FAILED" "preassembly kraken did not complete successfully"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	#Check extraction and unclassified value
 	if [[ -s "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" ]]; then
 		# Extracts many elements of the summary file to report unclassified and species classified reads and percentages
 		unclass=$(head -n 1 "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f2)
 		#true_unclass=$(head -n 1 "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 		domain=$(sed -n '2p' "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f2)
 		genuspre=$(sed -n '7p' "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f4)
 		speciespre=$(sed -n '8p' "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f4)
 		speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f2)
 		#true_speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 		# If there are no reads at the domain level, then report no classified reads
 		if (( $(echo "${domain} <= 0" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "kraken on reads" "FAILED" "There are no classified reads (Did pre assembly kraken fail too?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		# If there are classified reads then check to see if percent unclassifed falls above the threshold limit. Report warning if too high or success and stats if below
 		else
 			if (( $(echo "${unclass} > ${unclass_flag}" | bc -l) )); then
 				printf "%-20s: %-8s : %s\\n" "kraken on reads" "WARNING" "unclassified reads comprise ${unclass}% of total"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 					status="WARNING"
 				fi
 			else
 				#printf "%-20s: %-8s : %s\\n" "kraken on reads" "SUCCESS" "${speciespercent}%${true_speciespercent%} ${genuspre} ${speciespre} with ${unclass}%${true_unclass%} unclassified reads"
 				printf "%-20s: %-8s : %s\\n" "kraken on reads" "SUCCESS" "${speciespercent}% ${genuspre} ${speciespre} with ${unclass}% unclassified reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		fi
 	# If no summary file was found
 	else
 		printf "%-20s: %-8s : %s\\n" "kraken on reads" "FAILED" "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	# Quick separate check for contamination by finding # of species above ${contamination_threshold} in list file from kraken
 	if [[ -s "${OUTDATADIR}/kraken/preAssembly/${sample_name}_paired.list" ]]; then
 		number_of_species=0
 		while IFS= read -r line; do
 			arrLine=(${line})
 			# First element in array is the percent of reads identified as the current taxa
 			percent=${arrLine[0]}
 			percent_integer=$(echo "${percent}" | cut -d'.' -f1)
 			# 3rd element is the taxon level classification
 			# echo "${percent_integer} vs ${contamination_threshold}"
 			classification=${arrLine[3]}
 			if [[ "${classification}" == "S" ]] && (( percent_integer > contamination_threshold )); then
 				#echo "Adding ${arrLine[5]}-${percent_integer}-${contamination_threshold} to list"
 				number_of_species=$(( number_of_species + 1 ))
 			fi
 		done < ${OUTDATADIR}/kraken/preAssembly/${sample_name}_paired.list
 		if [[ "${number_of_species}" -gt 1 ]]; then
 			printf "%-20s: %-8s : %s\\n" "pre Class Contam. K1" "WARNING" "${number_of_species} species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 					status="WARNING"
 			fi
 		elif [[ "${number_of_species}" -eq 1 ]]; then
 			:
 		else
 			printf "%-20s: %-8s : %s\\n" "pre Class Contam. K1" "FAILED" "No species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 		#echo "Number of species: ${number_of_species}"
 	fi

 	#Check kraken2 on preAssembly
 	kraken2_pre_success=false
 	if [[ -s "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_paired.kraken2" ]] || [[ -s "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_paired.kraken2.gz" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "kraken2 preassembly" "SUCCESS" "Found"
 		kraken2_pre_success=true
 	else
 		printf "%-20s: %-8s : %s\\n" "kraken2 preassembly" "FAILED" "/kraken2/preAssembly/${sample_name}_paired.kraken2 not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	#Check Krona output
 	if [[ "${kraken2_pre_success}" = true ]]; then
 		if [[ -s "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_paired.krona" ]] && [[ -s "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_paired.html" ]]; then
 			#printf "%-20s: %-8s : %s\\n" "krona-kraken2-preasm" "SUCCESS" "Found"
 			:
 		else
 			printf "%-20s: %-8s : %s\\n" "krona-kraken2-preasm" "FAILED" "/kraken2/preAssembly/${sample_name}_paired.krona &&|| /kraken2/preAssembly/${sample_name}_paired.html not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "krona-kraken2-preasm" "FAILED" "preassembly kraken2 did not complete successfully"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	#Check extraction and unclassified value
 	if [[ -s "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_kraken_summary_paired.txt" ]]; then
 		# Extracts many elements of the summary file to report unclassified and species classified reads and percentages
 		unclass=$(head -n 1 "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f2)
 		#true_unclass=$(head -n 1 "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 		domain=$(sed -n '2p' "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f2)
 		genuspre=$(sed -n '7p' "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f4)
 		speciespre=$(sed -n '8p' "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f4)
 		speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f2)
 		#true_speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken/preAssembly/${sample_name}_kraken_summary_paired.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 		# If there are no reads at the domain level, then report no classified reads
 		if (( $(echo "${domain} <= 0" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "kraken2 on reads" "FAILED" "There are no classified reads (Did pre assembly kraken2 fail too?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		# If there are classified reads then check to see if percent unclassifed falls above the threshold limit. Report warning if too high or success and stats if below
 		else
 			if (( $(echo "${unclass} > ${unclass_flag}" | bc -l) )); then
 				printf "%-20s: %-8s : %s\\n" "kraken2 on reads" "WARNING" "unclassified reads comprise ${unclass}% of total"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 					status="WARNING"
 				fi
 			else
 				#printf "%-20s: %-8s : %s\\n" "kraken on reads" "SUCCESS" "${speciespercent}%${true_speciespercent%} ${genuspre} ${speciespre} with ${unclass}%${true_unclass%} unclassified reads"
 				printf "%-20s: %-8s : %s\\n" "kraken2 on reads" "SUCCESS" "${speciespercent}% ${genuspre} ${speciespre} with ${unclass}% unclassified reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		fi
 	# If no summary file was found
 	else
 		printf "%-20s: %-8s : %s\\n" "kraken2 on reads" "FAILED" "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_kraken_summary_paired.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	# Quick separate check for contamination by finding # of species above ${contamination_threshold} in list file from kraken2
 	if [[ -s "${OUTDATADIR}/kraken2/preAssembly/${sample_name}_paired.list" ]]; then
 		number_of_species=0
 		while IFS= read -r line; do
 			arrLine=(${line})
 			# First element in array is the percent of reads identified as the current taxa
 			percent=${arrLine[0]}
 			percent_integer=$(echo "${percent}" | cut -d'.' -f1)
 			# 3rd element is the taxon level classification
 			# echo "${percent_integer} vs ${contamination_threshold}"
 			classification=${arrLine[3]}
 			if [[ "${classification}" == "S" ]] && (( percent_integer > contamination_threshold )); then
 				#echo "Adding ${arrLine[5]}-${percent_integer}-${contamination_threshold} to list"
 				number_of_species=$(( number_of_species + 1 ))
 			fi
 		done < ${OUTDATADIR}/kraken2/preAssembly/${sample_name}_paired.list
 		if [[ "${number_of_species}" -gt 1 ]]; then
 			printf "%-20s: %-8s : %s\\n" "pre Class Contam. K2" "WARNING" "${number_of_species} species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 					status="WARNING"
 			fi
 		elif [[ "${number_of_species}" -eq 1 ]]; then
 			:
 		else
 			printf "%-20s: %-8s : %s\\n" "pre Class Contam. K2" "FAILED" "No species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 		#echo "Number of species: ${number_of_species}"
 	fi

 	#Check gottcha_S output for TSV ouput and the krona file
 	if [[ -s "${OUTDATADIR}/gottcha/gottcha_S/${sample_name}.gottcha_full.tsv" ]] && [[ -s "${OUTDATADIR}/gottcha/${sample_name}_species.krona.html" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "GOTTCHA_S" "SUCCESS" "Found"
 		:
 	elif [[ -s "${OUTDATADIR}/gottcha/gottcha_S/${sample_name}.gottcha_full.tsv" ]]; then
 		printf "%-20s: %-8s : %s\\n" "GOTTCHA_S" "WARNING" "No Krona output found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 			status="WARNING"
 		fi
 	elif [[ -s "${OUTDATADIR}/gottcha/${sample_name}_species.krona.html" ]]; then
 		printf "%-20s: %-8s : %s\\n" "GOTTCHA_S" "WARNING" "No TSV file found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 			status="WARNING"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "GOTTCHA_S" "FAILED" "/gottcha/gottcha_S/${sample_name}.gottcha_full.tsv & /gottcha/${sample_name}_species.krona.html not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	#Check extraction of gottcha id
 	if [[ -s "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt" ]]; then
 		# Extracts many elements of the summary file to report unclassified and species classified reads and percentages
 		unclass=$(head -n 1 "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt" | cut -d' ' -f2)
 		#true_unclass=$(head -n 1 "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt" | cut -d' ' -f3) # | sed -r 's/[)]+/%)/g')
 		phylumpercent=$(sed -n '3p' "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt" | cut -d' ' -f2)
 		genuspre=$(sed -n '7p' "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt"| cut -d' ' -f4)
 		speciespre=$(sed -n '8p' "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt" | cut -d' ' -f5)
 		speciespercent=$(sed -n '8p' "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt" | cut -d' ' -f2)
 		true_speciespercent=$(sed -n '8p' "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 		# Gottcha only classifies up to phylum and therefore if no phylum reads, there are no reads
 		if (( $(echo "${phylumpercent} <= 0" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "Gottcha Classifier" "FAILED" "There are no classified reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		# If there are phylum level reads then check to see the percentage. If it falls below the threshold (set in config.sh) report it as a warning, otherwise report all necessary stats
 		else
 			if (( $(echo "${unclass} > ${unclass_flag}" | bc -l) )); then
 				printf "%-20s: %-8s : %s\\n" "Gottcha Classifier" "WARNING" "unclassified reads comprise ${unclass}% of total"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 					status="WARNING"
 				fi
 			else
 				printf "%-20s: %-8s : %s\\n" "Gottcha Classifier" "SUCCESS" "${speciespercent}%${true_speciespercent} ${genuspre} ${speciespre} with ${unclass}% unclassified reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		fi
 	# If the summary file does not exist, report as such
 	else
 		printf "%-20s: %-8s : %s\\n" "Gottcha Classifier" "FAILED" "${OUTDATADIR}/gottcha/${sample_name}_gottcha_species_summary.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi

 	# Quick separate check for contamination by finding # of species above ${contamination_threshold} in list file from Gottcha
 	if [[ -s "${OUTDATADIR}/gottcha/gottcha_S/${sample_name}.gottcha.tsv" ]]; then
 		number_of_species=0
 		while IFS= read -r line; do
 			# Convert the perfect match to proper format from 1.00 to 100
 			if [[ "${line[2]}" = "1.0000" ]] || [[ "${line[2]}" -eq 1 ]]; then
 				percent_integer=100
 			# Convert all non-perfect matches to the correct matching percent values
 			else
 				percent="${line[2]:2:2}.${line[2]:4:2}"
 				percent_integer=$(echo "${percent}" | cut -d'.' -f1)
 			fi
 			# Convert a no-match to the correct percent value
 			if [[ "${percent}" = "00.00" ]]; then
 				percent_integer=0
 			fi
 			# Takes the first letter of the first column as shorthand for identifying the taxonomic level
 			classification="${line[0]::1}"
 			if [[ "${classification}" == "s" ]] && (( percent_integer > contamination_threshold )); then
 				number_of_species=$(( number_of_species + 1 ))
 			fi
 		done < ${OUTDATADIR}/gottcha/gottcha_S/${sample_name}.gottcha.tsv
 		if [[ $number_of_species -gt 1 ]]; then
 			# Holding off on putting a cutoff here, as we cant tell what is an acceptable value to use
 			#printf "%-20s: %-8s : %s\\n" "gottcha Contam." "WARNING" "${number_of_species} species have been found above the ${contamination_threshold}% threshold"
 			#if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 			#	status="WARNING"
 			#fi
 			:
 		elif [[ "${number_of_species}" -eq 1 ]]; then
 			:
 		else
 			# Holding off on putting a cutoff here, as we cant tell what is an acceptable value to use
 			#printf "%-20s: %-8s : %s\\n" "gottcha Contam." "FAILED" "No species have been found above the ${contamination_threshold}% threshold"
 			:
 		fi
 		#echo "Number of species: ${number_of_species}"
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "QC counts" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "Q30_R1%" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "Q30_R2%" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "BBDUK-PhiX" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "Trimming-R1" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "Trimming-R2" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "QC count after trim" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "kraken1 preassembly" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "krona-kraken-preasm" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "Pre Classify K1" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "kraken2 preassembly" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "krona-kraken2-preasm" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "Pre Classify K2" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "GOTTCHA_S" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	printf "%-20s: %-8s : %s\\n" "Gottcha Classifier" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 fi

 #Check spades assembly
 if [[ -s "${OUTDATADIR}/Assembly/scaffolds.fasta" ]]; then
 	# Count the number of '>' in the assembly file before trimming
 	full_scaffolds=">"
 	full_scaffolds=$(grep -c ${full_scaffolds} "${OUTDATADIR}/Assembly/scaffolds.fasta")
 	printf "%-20s: %-8s : %s\\n" "Assembly" "SUCCESS" "${full_scaffolds} scaffolds found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 else
 	printf "%-20s: %-8s : %s\\n" "Assembly" "FAILED" "/Assembly/scaffolds.fasta not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
  QC_FAIL=$QC_FAIL"smaller_than_1000000_bps(0)-"
 	status="FAILED"
 fi



 #Check short scaffolds reduction script
 if [[ -s "${OUTDATADIR}/Assembly/${sample_name}_scaffolds_trimmed.fasta" ]]; then
 	# Count the number of '>' still remaining after trimming the contig file
 	full_longies=">"
 	full_longies=$(grep -c ${full_longies} "${OUTDATADIR}/Assembly/${sample_name}_scaffolds_trimmed.fasta")
 	# Calculate the number of lost (short) scaffolds
 	full_shorties=$(( full_scaffolds - full_longies ))
 	if [ -z ${full_shorties} ]; then
 		full_shorties=0
 	fi
 	#echo "${full_longies}"
 	if [[ "${full_longies}" -le 200 ]]; then
 		printf "%-20s: %-8s : %s\\n" "Contig Trim" "SUCCESS" "${full_longies} scaffolds remain. ${full_shorties} were removed due to shortness"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	else
 		printf "%-20s: %-8s : %s\\n" "Contig Trim" "WARNING" "${full_longies} scaffolds remain which is high. ${full_shorties} were removed due to shortness"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" == "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
 			status="WARNING"
 		fi
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "Contig Trim" "FAILED" "/Assembly/${sample_name}_scaffolds_trimmed.fasta not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 #Check kraken on assembly
 kraken_post_success=false
 if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled.kraken" ]] || [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled.kraken.gz" ]]; then
 	#printf "%-20s: %-8s : %s\\n" "kraken postassembly" "SUCCESS" "Found"
 	kraken_post_success=true
 else
 	printf "%-20s: %-8s : %s\\n" "kraken postassembly" "FAILED" "/kraken/postAssembly/${sample_name}_assembled.kraken not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check Krona output of assembly
 if [[ "${kraken_post_success}" = true ]]; then
 	if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled.krona" ]] && [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled.html" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "krona-kraken-pstasm" "SUCCESS" "Found"
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "krona-kraken-pstasm" "FAILED" "/kraken/postAssembly/${sample_name}_assembled.krona &&|| /kraken/postAssembly/${sample_name}_assembled.html not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "krona-kraken-pstasm" "FAILED" "postassembly kraken did not complete successfully"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check extraction and unclassified values for kraken post assembly
 if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" ]]; then
 	# Extracts many elements of the summary file to report unclassified and species classified reads and percentages
 	unclass=$(head -n 1 "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f2)
 	#true_unclass=$(head -n 1 "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	domain=$(sed -n '2p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f2)
 	genuspost=$(sed -n '7p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f4)
 	speciespost=$(sed -n '8p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f4)
 	speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f2)
 	#true_speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	# If there are no reads at the domain level, then report no classified reads
 	if (( $(echo "${domain} <= 0" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "kraken on assembly" "FAILED" "There are no classified reads (Did post assembly kraken fail too?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	# If there are classified reads then check to see if percent unclassifed falls above the threshold limit. Report warning if too high or success and stats if below
 	else
 		if (( $(echo "${unclass} > ${unclass_flag}" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "kraken on assembly" "WARNING" "unclassified reads comprise ${unclass}% of total ${true_unclass}%"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 				status="WARNING"
 			fi
 		elif (( $(echo "${speciespercent} < 50" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "kraken on assembly" "WARNING" "${genuspost} ${speciespost} is under 50% (${speciespercent}), possibly contaminated or contigs are weighted unevenly"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
 				status="WARNING"
 			fi
 		else
 			#printf "%-20s: %-8s : %s\\n" "kraken on assembly" "SUCCESS" "${speciespercent}%${true_speciespercent%} ${genuspost} ${speciespost} with ${unclass}%${true_unclass%} unclassified contigs"
 			printf "%-20s: %-8s : %s\\n" "kraken on assembly" "SUCCESS" "${speciespercent}% ${genuspost} ${speciespost} with ${unclass}% unclassified contigs"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	fi
 # If no summary file was found
 else
 	printf "%-20s: %-8s : %s\\n" "kraken on assembly" "FAILED" "/kraken/postAssembly/${sample_name}_kraken_summary_assembled.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check weighted kraken on assembly
 kraken_weighted_success=false
 if [[ ! -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled_BP.kraken" ]]; then
 	if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled.kraken" ]]; then
 		${shareScript}/run_kraken.sh -n "${sample_name}" -r post -p "${project}" -c "${config}"
 	fi
 fi

 # Quick separate check for contamination by finding # of species above ${contamination_threshold} in list file from kraken
 if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled.list" ]]; then
 	number_of_species=0
 	while IFS= read -r line; do
 		arrLine=(${line})
 		# First element in array is the percent of reads identified as the current taxa
 		percent=${arrLine[0]}
 		percent_integer=$(echo "${percent}" | cut -d'.' -f1)
 		# 3rd element is the taxon level classification
 		classification=${arrLine[3]}
 		#echo "${percent_integer} - ${contamination}"
 		if [[ "${classification}" == "S" ]] && (( percent_integer > contamination_threshold )); then
 			number_of_species=$(( number_of_species + 1 ))
 		fi
 	done < ${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled.list
 	if [[ $number_of_species -gt 1 ]]; then
 		printf "%-20s: %-8s : %s\\n" "post Class Contam. K1" "ALERT" "${number_of_species} species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" == "SUCCESS" ]]; then
 			status="ALERT"
 		fi
 	elif [[ "${number_of_species}" -eq 1 ]]; then
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "post Class Contam. K1" "ALERT" "No species have been found above ${contamination_threshold}% abundance"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" = "ALERT" ]] || [[ "${status}" = "SUCCESS" ]]; then
 			status="WARNING"
 		fi
 	fi
 	#echo "Number of species: ${number_of_species}"
 fi



 if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled_BP.kraken" ]]; then
 	#printf "%-20s: %-8s : %s\\n" "kraken weighted" "SUCCESS" "Found"
 	kraken_weighted_success=true
 else
 	printf "%-20s: %-8s : %s\\n" "kraken weighted" "FAILED" "${sample_name}_assembled_BP.kraken not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check Krona output of weighted assembly
 if [[ "${kraken_weighted_success}" = true ]]; then
 	if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled_weighted.krona" ]] && [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled_weighted_BP_krona.html" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "krona-kraken-weight" "SUCCESS" "Found"
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "krona-kraken-weight" "FAILED" "/kraken/postAssembly/${sample_name}_assembled_weighted.krona &&|| /kraken/postAssembly/${sample_name}_assembled_weighted_BP_krona.html not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "krona-kraken-weight" "FAILED" "weighted conversion analysis of assembly kraken did not complete successfully"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check extraction and unclassified values for weighted kraken post assembly
 if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" ]]; then
 	# Extracts many elements of the summary file to report unclassified and species classified reads and percentages
 	unclass=$(head -n 1 "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f2)
 	#true_unclass=$(head -n 1 "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	domain=$(sed -n '2p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f2)
 	genusweighted=$(sed -n '7p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f4)
 	speciesweighted=$(sed -n '8p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f4)
 	speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f2)
 	#true_speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	# If there are no reads at the domain level, then report no classified reads
 	if (( $(echo "${domain} <= 0" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "weighted Classify K1" "FAILED" "There are no classified reads (Did post assembly kraken fail too?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	# If there are classified reads then check to see if percent unclassifed falls above the threshold limit. Report warning if too high or success and stats if below
 	else
 		if (( $(echo "${unclass} > ${unclass_flag}" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "weighted Classify K1" "WARNING" "unclassified reads comprise ${unclass}% of total ${true_unclass}%"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 				status="WARNING"
 			fi
 		elif (( $(echo "${speciespercent} < 50" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "weighted Classify K1" "FAILED" "${genusweighted} ${speciesweighted} is under 50% (${speciespercent}), likely contaminated"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		else
 			#printf "%-20s: %-8s : %s\\n" "weighted Classify" "SUCCESS" "${speciespercent}%${true_speciespercent%} ${genusweighted} ${speciesweighted} with ${unclass}%${true_unclass%} unclassified weighted"
 			printf "%-20s: %-8s : %s\\n" "weighted Classify K1" "SUCCESS" "${speciespercent}% ${genusweighted} ${speciesweighted} with ${unclass}% unclassified contigs"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	fi
 # If no summary file was found
 else
 	printf "%-20s: %-8s : %s\\n" "weighted Classify K1" "FAILED" "/kraken/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 # Quick separate check for contamination by finding # of species above ${contamination_threshold} in list file from kraken
 if [[ -s "${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled_BP.list" ]]; then
 	number_of_species=0
 	while IFS= read -r line; do
 		arrLine=(${line})
 		# First element in array is the percent of reads identified as the current taxa
 		percent=${arrLine[0]}
 		percent_integer=$(echo "${percent}" | cut -d'.' -f1)
 		# 3rd element is the taxon level classification
 		classification=${arrLine[3]}
 		if [[ "${classification}" == "S" ]] && (( percent_integer > contamination_threshold )); then
 			#echo "Adding ${line} because its S and greater than ${contamination_threshold}... ${percent_integer}"
 			number_of_species=$(( number_of_species + 1 ))
 		fi
 	done < ${OUTDATADIR}/kraken/postAssembly/${sample_name}_assembled_BP.list
 	if [[ $number_of_species -gt 1 ]]; then
 		printf "%-20s: %-8s : %s\\n" "weighted Contam. K1" "FAILED" "${number_of_species} species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	elif [[ "${number_of_species}" -eq 1 ]]; then
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "weighted Contam. K1" "FAILED" "No species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	fi
 	#echo "Number of species: ${number_of_species}"
 fi

 #Check kraken2 on assembly
 kraken2_post_success=false
 if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled.kraken2" ]] || [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled.kraken2.gz" ]]; then
 	#printf "%-20s: %-8s : %s\\n" "kraken2 postassembly" "SUCCESS" "Found"
 	kraken2_post_success=true
 else
 	printf "%-20s: %-8s : %s\\n" "kraken2 postassembly" "FAILED" "/kraken2/postAssembly/${sample_name}_assembled.kraken2 not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check Krona output of assembly
 if [[ "${kraken2_post_success}" = true ]]; then
 	if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled.krona" ]] && [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled.html" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "krona-kraken2-pstasm" "SUCCESS" "Found"
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "krona-kraken2-pstasm" "FAILED" "/kraken2/postAssembly/${sample_name}_assembled.krona &&|| /kraken2/postAssembly/${sample_name}_assembled.html not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "krona-kraken2-pstasm" "FAILED" "postassembly kraken2 did not complete successfully"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check extraction and unclassified values for kraken2 post assembly
 if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" ]]; then
 	# Extracts many elements of the summary file to report unclassified and species classified reads and percentages
 	unclass=$(head -n 1 "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f2)
 	#true_unclass=$(head -n 1 "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	domain=$(sed -n '2p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f2)
 	genuspost=$(sed -n '7p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f4)
 	speciespost=$(sed -n '8p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f4)
 	speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f2)
 	#true_speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	# If there are no reads at the domain level, then report no classified reads
 	if (( $(echo "${domain} <= 0" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "kraken2 on assembly" "FAILED" "There are no classified reads (Did post assembly kraken2 fail too?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	# If there are classified reads then check to see if percent unclassifed falls above the threshold limit. Report warning if too high or success and stats if below
 	else
 		if (( $(echo "${unclass} > ${unclass_flag}" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "kraken2 on assembly" "WARNING" "unclassified reads comprise ${unclass}% of total ${true_unclass}%"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 				status="WARNING"
 			fi
 		elif (( $(echo "${speciespercent} < 50" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "kraken2 on assembly" "WARNING" "${genuspost} ${speciespost} is under 50% (${speciespercent}), possibly contaminated or contigs are weighted unevenly"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
 				status="WARNING"
 			fi
 		else
 			#printf "%-20s: %-8s : %s\\n" "kraken2 on assembly" "SUCCESS" "${speciespercent}%${true_speciespercent%} ${genuspost} ${speciespost} with ${unclass}%${true_unclass%} unclassified contigs"
 			printf "%-20s: %-8s : %s\\n" "kraken2 on assembly" "SUCCESS" "${speciespercent}% ${genuspost} ${speciespost} with ${unclass}% unclassified contigs"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	fi
 # If no summary file was found
 else
 	printf "%-20s: %-8s : %s\\n" "kraken2 on assembly" "FAILED" "/kraken2/postAssembly/${sample_name}_kraken_summary_assembled.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check weighted kraken2 on assembly
 kraken2_weighted_success=false
 if [[ ! -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled_BP.list" ]]; then
 	if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}__kraken_summary_assembled_BP.txt" ]]; then
 		${shareScript}/run_kraken2.sh -n "${sample_name}" -r post -p "${project}" -c "${config}"
 	fi
 fi

 # Quick separate check for contamination by finding # of species above ${contamination_threshold} in list file from kraken2
 if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled.list" ]]; then
 	number_of_species=0
 	while IFS= read -r line; do
 		arrLine=(${line})
 		# First element in array is the percent of reads identified as the current taxa
 		percent=${arrLine[0]}
 		percent_integer=$(echo "${percent}" | cut -d'.' -f1)
 		# 3rd element is the taxon level classification
 		classification=${arrLine[3]}
 		#echo "${percent_integer} - ${contamination}"
 		if [[ "${classification}" == "S" ]] && (( percent_integer > contamination_threshold )); then
 			number_of_species=$(( number_of_species + 1 ))
 		fi
 	done < ${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled.list
 	if [[ $number_of_species -gt 1 ]]; then
 		printf "%-20s: %-8s : %s\\n" "post Class Contam. K2" "ALERT" "${number_of_species} species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" == "SUCCESS" ]]; then
 			status="ALERT"
 		fi
 	elif [[ "${number_of_species}" -eq 1 ]]; then
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "post Class Contam. K2" "ALERT" "No species have been found above ${contamination_threshold}% abundance"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" = "ALERT" ]] || [[ "${status}" = "SUCCESS" ]]; then
 			status="WARNING"
 		fi
 	fi
 	#echo "Number of species: ${number_of_species}"
 fi

 if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled_BP.list" ]]; then
 	#printf "%-20s: %-8s : %s\\n" "kraken2 weighted" "SUCCESS" "Found"
 	kraken2_weighted_success=true
 else
 	printf "%-20s: %-8s : %s\\n" "kraken2 weighted" "FAILED" "${sample_name}_assembled_BP.list not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check Krona output of weighted assembly
 if [[ "${kraken2_weighted_success}" = true ]]; then
 	if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled_weighted.krona" ]] && [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled_BP_krona.html" ]]; then
 		#printf "%-20s: %-8s : %s\\n" "krona-kraken2-weight" "SUCCESS" "Found"
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "krona-kraken2-weight" "FAILED" "/kraken2/postAssembly/${sample_name}_assembled_weighted.krona &&|| /kraken2/postAssembly/${sample_name}_assembled_weighted_BP_krona.html not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "krona-kraken2-weight" "FAILED" "weighted conversion analysis of assembly kraken2 did not complete successfully"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi
 #Check extraction and unclassified values for weighted kraken2 post assembly
 if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" ]]; then
 	# Extracts many elements of the summary file to report unclassified and species classified reads and percentages
 	unclass=$(head -n 1 "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f2)
 	#true_unclass=$(head -n 1 "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	domain=$(sed -n '2p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f2)
 	genusweighted=$(sed -n '7p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f4)
 	speciesweighted=$(sed -n '8p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f4)
 	speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f2)
 	#true_speciespercent=$(sed -n '8p' "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt" | cut -d' ' -f3 | sed -r 's/[)]+/%)/g')
 	# If there are no reads at the domain level, then report no classified reads
 	if (( $(echo "${domain} <= 0" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "weighted Classify K2" "FAILED" "There are no classified reads (Did post assembly kraken2 fail too?)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	# If there are classified reads then check to see if percent unclassifed falls above the threshold limit. Report warning if too high or success and stats if below
 	else
 		if (( $(echo "${unclass} > ${unclass_flag}" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "weighted Classify K2" "WARNING" "unclassified reads comprise ${unclass}% of total ${true_unclass}%"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [ "${status}" = "SUCCESS" ] || [ "${status}" = "ALERT" ]; then
 				status="WARNING"
 			fi
 		elif (( $(echo "${speciespercent} < 50" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "weighted Classify K2" "FAILED" "${genusweighted} ${speciesweighted} is under 50% (${speciespercent}), likely contaminated"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		else
 			#printf "%-20s: %-8s : %s\\n" "weighted Classify" "SUCCESS" "${speciespercent}%${true_speciespercent%} ${genusweighted} ${speciesweighted} with ${unclass}%${true_unclass%} unclassified weighted"
 			printf "%-20s: %-8s : %s\\n" "weighted Classify K2" "SUCCESS" "${speciespercent}% ${genusweighted} ${speciesweighted} with ${unclass}% unclassified contigs"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	fi
 # If no summary file was found
 else
 	printf "%-20s: %-8s : %s\\n" "weighted Classify K2" "FAILED" "/kraken2/postAssembly/${sample_name}_kraken_summary_assembled_BP.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 # Quick separate check for contamination by finding # of species above ${contamination_threshold} in list file from kraken2
 if [[ -s "${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled_BP.list" ]]; then
 	number_of_species=0
 	total_read_length=0
 	while IFS= read -r line; do
 		arrLine=(${line})
 		# First element in array is the percent of reads identified as the current taxa
 		percent=${arrLine[0]}
 		reads=${arrLine[1]}
 		# 3rd element is the taxon level classification
 		classification=${arrLine[3]}
 		if [ "${classification}" = "R" ] || ([ "${classification}" = "-" ] && [ "${first_desc}" = "root" ]); then
      classified_reads="${reads}"
 			classified_percent="${percent}"
 		fi
 		if [[ "${classification}" == "S" ]]; then
 			#echo "Adding ${line} because its S and greater than ${contamination_threshold}... ${percent_integer}"
 			species_percent=$(echo "${percent} ${classified_percent}" | awk '{ printf "%2f", ($1*100)/$2 }' )
 			percent_integer=$(echo "${species_percent}" | cut -d'.' -f1)
 			if (( percent_integer > contamination_threshold )); then
 				number_of_species=$(( number_of_species + 1 ))
 			fi
 		fi
 	done < ${OUTDATADIR}/kraken2/postAssembly/${sample_name}_assembled_BP.list
 	if [[ $number_of_species -gt 1 ]]; then
 		printf "%-20s: %-8s : %s\\n" "weighted Contam. K2" "FAILED" "${number_of_species} species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	elif [[ "${number_of_species}" -eq 1 ]]; then
 		:
 	else
 		printf "%-20s: %-8s : %s\\n" "weighted Contam. K2" "FAILED" "No species have been found above the ${contamination_threshold}% threshold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	fi
 	#echo "Number of species: ${number_of_species}"
 fi

 #Check QUAST
 if [[ -s "${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv" ]]; then
 	# Extract the useful bits and report (to compare to Toms)
 	contig_num=$(sed -n '14p' "${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3 | tr -d '[:space:]')
 	assembly_length=$(sed -n '16p' "${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3 | tr -d '[:space:]')
 	N50=$(sed -n '18p' "${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv" | sed -r 's/[\t]+/ /g'| cut -d' ' -f2 | tr -d '[:space:]')
 	GC_con=$(sed -n '17p' "${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3 | tr -d '[:space:]')
 	printf "%-20s: %-8s : %s\\n" "QUAST" "SUCCESS" "#-${contig_num} length-${assembly_length} n50-${N50} %GC-${GC_con}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
  if [[ "${assembly_length}" -lt 1000000 ]]; then
    QC_FAIL=$QC_FAIL"smaller_than_1000000_bps(${assembly_length})-"
  fi
 else
 	printf "%-20s: %-8s : %s\\n" "QUAST" "FAILED" "/Assembly_Stats/report.tsv does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi


 # Get determinde taxonomy
 if [[ ! -s "${OUTDATADIR}/${sample_name}.tax" ]]; then
 	"${shareScript}/determine_taxID.sh" -n "${sample_name}" -p "${project}" -c "${config}"
 fi

 source_call=$(head -n1 "${OUTDATADIR}/${sample_name}.tax")
 tax_source="UNK"
 while IFS= read -r line; do
 	# Grab first letter of line (indicating taxonomic level)
 	first=${line:0:1}
 	# Assign taxonomic level value from 4th value in line (1st-classification level,2nd-% by kraken, 3rd-true % of total reads, 4th-identifier)
 	if [ "${first}" = "s" ]; then
 		dec_species=$(echo "${line}" | awk -F ' ' '{print $2}')
 	elif [ "${first}" = "G" ]; then
 		dec_genus=$(echo "${line}" | awk -F ' ' '{print $2}')
 	elif [ "${first}" = "F" ]; then
 		dec_family=$(echo "${line}" | awk -F ' ' '{print $2}')
 	elif [ "${first}" = "(" ]; then
 		tax_source=$(echo "${line}" | cut -d')' -f1 | cut -d'(' -f2)
 	fi
 done < "${OUTDATADIR}/${sample_name}.tax"

 if [[ "$dec_genus" != "Not_assigned" ]] && [[ "$dec_species" != "Not_assigned" ]]; then
 	printf "%-20s: %-8s : %s\\n" "Taxa" "SUCCESS" "${tax_source}-${dec_genus} ${dec_species}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 elif [[ "$dec_genus" != "Not_assigned" ]]; then
 	printf "%-20s: %-8s : %s\\n" "Taxa" "FAILED" "None of the classifiers completed successfully"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 elif [[ "$dec_species" != "Not_assigned" ]]; then
 	printf "%-20s: %-8s : %s\\n" "Taxa" "WARNING" "No Species was able to be determined"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 fi

 # # Check Assembly ratio
 # declare -A mmb_bugs
 # while IFS=$'\t' read -r -a bug_lines; do
 # 	#bug_genus=$(echo "${bug_lines}" | cut -d'	' -f1)
 # 	#bug_species=$(echo "${bug_lines}" | cut -d'	' -f2)
 # 	#bug_info=$(echo "${bug_lines}" | cut -d'	' -f4-)
 # 	#bug_size=$(echo "${bug_lines}" | cut -d'	' -f6)
 # 	#bug_name="${bug_genus:0:1}.${bug_species}"
 # 	#bug_name=$(echo "${bug_lines}" | cut -d'	' -f3)
 # 	#echo "Should be adding ${bug_size} for ${bug_name}"
 # 	bug_name="${bug_lines[2]}"
 # 	bug_size="${bug_lines[5]}"
 # 	#echo "${bug_name}, ${bug_size}"
 # 	mmb_bugs["${bug_name}"]="${bug_size}"
 # done < ${local_DBs}/MMB_Bugs.txt
 genus_initial="${dec_genus:0:1}"
 assembly_ID="${genus_initial}.${dec_species}"
 #echo "${!mmb_bugs[@]}"
 #echo "${mmb_bugs[@]}"
 #echo "${assembly_ID}"
 newest_ratio_file=$(find ${OUTDATADIR}/ -maxdepth 1 -type f -name "${sample_name}_Assembly_ratio_*.txt" | sort -k4,4 -rt '_' -n | head -n1)
 if [[ -f "${newest_ratio_file}" ]]; then
 	ratio_db_date=$(echo "${newest_ratio_file}" | rev | cut -d'_' -f1 | rev | cut -d'.' -f1)
 	assembly_ratio=$(tail -n1 "${newest_ratio_file}" | cut -d' ' -f2)
  stdev_line=$(head -n4 "${newest_ratio_file}" | tail -n1)
  species_stdev_line=$(head -n3 "${newest_ratio_file}" | tail -n1)
  if [[ "${stdev_line}" = "Isolate_St.Devs:"* ]]; then
    st_dev=$(head -n4 "${newest_ratio_file}" | tail -n1 | cut -d' ' -f2)
  else
    "${shareScript}/calculate_assembly_ratio.sh" -e ${OUTDATADIR}
    st_dev=$(head -n4 "${newest_ratio_file}" | tail -n1 | cut -d' ' -f2)
  fi

  if [[ "${ratio_db_date}" = "${NCBI_ratio_date}" ]]; then
 	  #assembly_ratio=$(tail -n1 ${OUTDATADIR}/Assembly_ratio.txt | cut -d' ' -f2)
    if (( $(echo "$assembly_ratio < 0" | bc -l) )); then
      printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "WARNING" "No Reference - ${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB up to date! Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
      if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
        status="WARNING"
      fi
      #QC_FAIL=$QC_FAIL"STDev_NOREF-"
    elif [[ "${species_st_dev_line}" = *"Single_Reference"* ]]; then
      printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "ALERT" "One Reference for STDev - ${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB up to date! Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" = "SUCCESS" ]]; then
        status="ALERT"
      fi
 		elif (( $(echo "$st_dev > 2.58" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "FAILED" "Too large - ${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB up to date! Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
      QC_FAIL=$QC_FAIL"STDev_above_2.58($st_dev)-"
 		#elif (( $(echo "$assembly_ratio < 0.8" | bc -l) )); then
 		#	printf "%-20s: %-8s : %s\\n" "Assembly ratio" "FAILED" "Too small - ${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB up to date! Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		#	status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "SUCCESS" "${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB up to date! Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	else
    if (( $(echo "$assembly_ratio < 0" | bc -l) )); then
      printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "WARNING" "No Reference - ${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB NOT up to date! Found as ${ratio_db_date}. Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
      if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
        status="WARNING"
      fi
      #QC_FAIL=$QC_FAIL"STDev_NOREF-"
    elif [[ "${st_dev}" = "Single_Reference" ]]; then
      printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "WARNING" "One Reference for STDev - ${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB NOT up to date! Found as ${ratio_db_date}. Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
        status="WARNING"
      fi
 		elif (( $(echo "$st_dev > 2.58" | bc -l) )); then
 			printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "FAILED" "Too large - ${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB NOT up to date! Found as ${ratio_db_date}. Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
      QC_FAIL=$QC_FAIL"STDev_above_2.58($st_dev)-old_DB"
 		else
 			printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "WARNING" "${assembly_ratio}x(${st_dev}-SD) against ${assembly_ID} (DB NOT up to date! Found as ${ratio_db_date}. Most current DB: ${NCBI_ratio_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
 				status="WARNING"
 			fi
 		fi
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "Assembly ratio(SD)" "FAILED" "No Ratio File exists"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]] || [[ "${status}" = "WARNING" ]]; then
 		status="FAILED"
 	fi
 fi

 # check coverage
 if [[ -s "${OUTDATADIR}/preQCcounts/${sample_name}_counts.txt" ]]; then
 	line=$(tail -n1 "${OUTDATADIR}/preQCcounts/${sample_name}_counts.txt")
 	IFS='	' read -r -a qcs <<< "${line}"
 	read_qc_info=${qcs[@]:1}
 	# Extract q30 reads from qcCounts to calculate average coverage as q30_reads/assembly_length
 	q30_reads=$(echo "${read_qc_info}" | awk -F ' ' '{print $2}')
 	# Change later to AWK as this wont work on ASPEN, but consolidate won't likely be run on cluster
 	if [[ ${assembly_length} -gt 0 ]] && [[ ${q30_reads} -gt 0 ]]; then
 		avg_coverage=$(bc <<<"scale=2 ; ${q30_reads} / ${assembly_length}")
 	else
 		avg_coverage=0
 	fi
  reads_min=30
 	reads_low=40
 	reads_high=150
 	#echo "raw-${avg_coverage}"
 	if (( $(echo "${avg_coverage} > ${reads_low}" | bc -l) )) && (( $(echo "${avg_coverage} < ${reads_high}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Raw coverage" "SUCCESS" "${avg_coverage}x coverage based on raw reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	elif (( $(echo "${avg_coverage} > ${reads_high}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Raw coverage" "ALERT" "${avg_coverage}x coverage based on raw reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" == "SUCCESS" ]]; then
 			status="ALERT"
 		fi
  elif (( $(echo "${avg_coverage} > ${reads_min}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Raw coverage" "ALERT" "${avg_coverage}x coverage based on raw reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" == "SUCCESS" ]]; then
 			status="ALERT"
 		fi
 	elif (( $(echo "${avg_coverage} < ${reads_min}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Raw coverage" "FAILED" "${avg_coverage}x coverage based on raw reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 fi
 if [[ -s "${OUTDATADIR}/preQCcounts/${sample_name}_trimmed_counts.txt" ]]; then
 	line=$(tail -n1 "${OUTDATADIR}/preQCcounts/${sample_name}_trimmed_counts.txt")
 	IFS='	' read -r -a qcs <<< "${line}"
 	read_qc_info=${qcs[@]:1}
 	# Extract q30 reads from qcCounts to calculate average coverage as q30_reads/assembly_length
 	q30_reads=$(echo "${read_qc_info}" | awk -F ' ' '{print $2}')
 	# Change later to AWK as this wont work on ASPEN, but consolidate won't likely be run on cluster
 	if [[ ${assembly_length} -gt 0 ]] && [[ ${q30_reads} -gt 0 ]]; then
 		avg_coverage=$(bc <<<"scale=2 ; ${q30_reads} / ${assembly_length}")
 	else
 		avg_coverage=0
 	fi
 	#echo "trimmed-${avg_coverage}"
 	if (( $(echo "${avg_coverage} > ${reads_low}" | bc -l) )) && (( $(echo "${avg_coverage} < ${reads_high}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Trimmed coverage" "SUCCESS" "${avg_coverage}x coverage based on trimmed reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	elif (( $(echo "${avg_coverage} > ${reads_high}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Trimmed coverage" "ALERT" "${avg_coverage}x coverage based on trimmed reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" == "SUCCESS" ]]; then
 			status="ALERT"
 		fi
  elif (( $(echo "${avg_coverage} > ${reads_min}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Trimmed coverage" "ALERT" "${avg_coverage}x coverage based on trimmed reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		if [[ "${status}" == "SUCCESS" ]]; then
 			status="ALERT"
 		fi
 	elif (( $(echo "${avg_coverage} < ${reads_min}" | bc -l) )); then
 		printf "%-20s: %-8s : %s\\n" "Trimmed coverage" "FAILED" "${avg_coverage}x coverage based on trimmed reads"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
  if (( $(echo "${avg_coverage} < ${reads_min}" | bc -l) )); then
    QC_FAIL=$QC_FAIL"coverage_below_30($avg_coverage)-"
  fi
 fi

 # Check prokka
 if [[ -s "${OUTDATADIR}/prokka/${sample_name}_PROKKA.gbf" ]]; then
 	# Counts the number of genes present in the file using the 'CDS' identifier
 	genes="CDS"
 	genes=$(grep -c ${genes} "${OUTDATADIR}/prokka/${sample_name}_PROKKA.gbf")
 	printf "%-20s: %-8s : %s\\n" "prokka" "SUCCESS" "${genes} genes found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 elif [[ -s "${OUTDATADIR}/prokka/${sample_name}_PROKKA.gbk" ]]; then
 	# Counts the number of genes present in the file using the 'CDS' identifier
 	genes="CDS"
 	genes=$(grep -c ${genes} "${OUTDATADIR}/prokka/${sample_name}_PROKKA.gbk")
 	printf "%-20s: %-8s : %s\\n" "prokka" "SUCCESS" "${genes} genes found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 else
 	printf "%-20s: %-8s : %s\\n" "prokka" "FAILED" "/prokka/${sample_name}_PROKKA.gbf not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 #Check BUSCO
 if [[ -s "${OUTDATADIR}/BUSCO/short_summary_${sample_name}.txt" ]]; then
 	# Reads each line of the busco output file to extract the 3 that contain summary data to report
 	while IFS= read -r line; do
 		# If the line contains info for found buscos, total buscos, or database info grab it
 		if [[ "${line}" == *"Complete BUSCOs (C)"* ]]
 		then
 			#echo "C-"${line}
 			found_buscos=$(echo "${line}" | awk -F ' ' '{print $1}')
 		elif [[ "${line}" == *"Total BUSCO groups searched"* ]]; then
 			#echo "T-"${line}
 			total_buscos=$(echo "${line}" | awk -F ' ' '{print $1}')
 		elif [[ "${line}" == *"The lineage dataset is:"* ]]; then
 			#echo "L-"${line}
 			db=$(echo "${line}" | awk -F ' ' '{print $6}')
 		fi
 	done < "${OUTDATADIR}/BUSCO/short_summary_${sample_name}.txt"
 	percent_BUSCO_present=$(bc<<<"${found_buscos}*100/${total_buscos}")
 	if [[ "${percent_BUSCO_present}" -gt 90 ]]; then
 		printf "%-20s: %-8s : %s\\n" "BUSCO" "SUCCESS" "${percent_BUSCO_present}% (${found_buscos}/${total_buscos}) against ${db}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	else
 		printf "%-20s: %-8s : %s\\n" "BUSCO" "FAILED" "${percent_BUSCO_present}% (${found_buscos}/${total_buscos}) against ${db}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 # If the busco summary file does not exist
 else
 	printf "%-20s: %-8s : %s\\n" "BUSCO" "FAILED" "/BUSCO/short_summary_${sample_name}.txt not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 #Check ANI
 # Now only showing ANI_REFSEQ, as OSII ANI is deprecated
 # ani_found=false
 # if [[ "${dec_genus}" = "Clostridioides" ]]; then
 # 	ani_genus="Clostridium"
 # else
 # 	ani_genus="${dec_genus}"
 # fi
 # if [[ -f "${OUTDATADIR}/ANI/best_ANI_hits_ordered(${sample_name}_vs_${ani_genus}).txt" ]]; then
 # 	ani_info=$(head -n 1 "${OUTDATADIR}/ANI/best_ANI_hits_ordered(${sample_name}_vs_${ani_genus}).txt")
 # 	percents_count=$(echo "${ani_info}" | tr -cd '%' | wc -c)
 # 	percent_match=$(echo "${ani_info}" | cut -d'.' -f1)
 # 	if [[ "${percents_count}" -eq 2 ]]; then
 # 		coverage_match=$(echo "${ani_info}" | cut -d'-' -f2 | cut -d'.' -f1)
 # 		if [[ "${percent_match}" = "0." ]]; then
 # 			printf "%-20s: %-8s : %s\\n" "ANI_OSII" "FAILED" "No assembly file to work with"
 # 			#status="FAILED"
 # 		else
 # 			if [[ "${percent_match}" -ge 95 ]] && [[ "${coverage_match}" -ge ${ani_coverage_threshold} ]]; then
 # 				printf "%-20s: %-8s : %s\\n" "ANI_OSII" "SUCCESS" "${ani_info} against ${ani_genus}"
 # 			else
 # 				if [[ "${percent_match}" -lt 95 ]]; then
 # 					printf "%-20s: %-8s : %s\\n" "ANI_OSII" "FAILED" "${percent_match}% identity is too low, ${ani_info}"
 # 				elif [[ "${coverage_match}" -lt ${ani_coverage_threshold} ]]; then
 # 					printf "%-20s: %-8s : %s\\n" "ANI_OSII" "FAILED" "${coverage_match}% coverage is too low, ${ani_info}"
 # 				fi
 # 				#status="FAILED"
 # 			fi
 # 		fi
 # 	else
 # 	#echo "${percent_match--}"
 # 		if [[ "${percent_match}" = "0." ]]; then
 # 			printf "%-20s: %-8s : %s\\n" "ANI_OSII" "FAILED" "No assembly file to work with"
 # 		#status="FAILED"
 # 		else
 # 			if [[ "${percent_match}" -ge 95 ]]; then
 # 				printf "%-20s: %-8s : %s\\n" "ANI_OSII" "ALERT" "${ani_info} against ${ani_genus}, No coverage information"
 # 			else
 # 				if [[ "${percent_match}" -lt 95 ]]; then
 # 					printf "%-20s: %-8s : %s\\n" "ANI_OSII" "FAILED" "${percent_match}% identity is too low, ${ani_info}"
 # 				fi
 # 				#status="FAILED"
 # 			fi
 # 		fi
 # 	fi
 # elif [[ ! -d "${OUTDATADIR}/ANI/" ]]; then
 # 	printf "%-20s: %-8s : %s\\n" "ANI_OSII" "FAILED" "/ANI/ does not exist"
 # 	#status="FAILED"
 # else
 # 	printf "%-20s: %-8s : %s\\n" "ANI_OSII" "FAILED" "NO ANI OSII best_hits file"
 # 	#status="FAILED"
 # fi

 #Check ANI REFSEQ
 if [[ -d "${OUTDATADIR}/ANI" ]]; then
     best_ani_refseq=$(find ${OUTDATADIR}/ANI/ -maxdepth 1 -type f -name "best_ANI_hits_ordered(${sample_name}_vs_REFSEQ_*).txt" | sort -k4,4 -rt '_' -n | head -n1)
     #echo ${best_ani_refseq}
     if [[ ! -z "${best_ani_refseq}" ]]; then
 	       ani_refseq_date=$(echo "${best_ani_refseq}" | rev | cut -d'_' -f1 | rev | cut -d')' -f1)
 	       ani_refseq_info=$(head -n1 "${best_ani_refseq}")
 	       percent_match=$(echo "${ani_refseq_info}" | cut -d'.' -f1)
 	       coverage_match=$(echo "${ani_refseq_info}" | cut -d'-' -f2 | cut -d'.' -f1)
         if [[ "${percent_match}" = "0." ]]; then
 		         if [[ "${ani_refseq_date}" = "${REFSEQ_date}" ]]; then
 				         printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "No assembly file to work with"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				         #status="FAILED"
   			     else
   				       printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "No assembly file to work with and REFSEQ database is out of date (${ani_refseq_date}), not ${REFSEQ_date})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   				       #status="FAILED"
   			     fi
         else
 		         if [[ "${percent_match}" -ge 95 ]] && [[ "${coverage_match}" -ge ${ani_coverage_threshold} ]]; then
 			           if [[ "${ani_refseq_date}" = "${REFSEQ_date}" ]]; then
 					           printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "SUCCESS" "${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			           else
 					           printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "ALERT" "REFSEQ database is out of date ($ani_refseq_date}), not ${REFSEQ_date}. ${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					           if [[ "${status}" == "SUCCESS" ]]; then
 						             status="ALERT"
 					           fi
 				         fi
 		        else
 				        if [[ "${percent_match}" -lt 95 ]]; then
 					          if [[ "${ani_refseq_date}" = "${REFSEQ_date}" ]]; then
 						            if [[ "${coverage_match}" -lt ${ani_coverage_threshold} ]]; then
 							              printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "% Identity(${percent_match}%) and % coverage(${coverage_match}%) is too low. ${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 							              #status="FAILED"
 						            else
 							              printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "% Identity(${percent_match}%) is too low: ${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 							              #status="FAILED"
 						            fi
 					          else
 						            if [[ "${coverage_match}" -lt ${ani_coverage_threshold} ]]; then
 							              printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "% Identity(${percent_match}%) and % coverage(${coverage_match}%) is too low and database is out of date (${ani_refseq_date}), not ${REFSEQ_date}. ${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
     							          #status="FAILED"
 		    				        else
 				    			          printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "% Identity(${percent_match}%) is too low and database is out of date (${ani_refseq_date}), not ${REFSEQ_date}. ${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 						    	          #status="FAILED"
 						            fi
 					          fi
     				    elif [[ "${coverage_match}" -lt ${ani_coverage_threshold} ]]; then
 		    			      if [[ "${ani_refseq_date}" = "${REFSEQ_date}" ]]; then
 				    		        printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "% coverage is too low (${coverage_match}%). ${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 						            #status="FAILED"
 					          else
 						            printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "% coverage (${coverage_match}%) is too low and REFSEQ database is out of date (${ani_refseq_date}). ${ani_refseq_info}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 						            #status="FAILED"
 					          fi
 				        fi
            fi
         fi
     else
         printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "NO ANI_REFSEQ best_hits file"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
         #status="FAILED"
 		 fi
 else
 	printf "%-20s: %-8s : %s\\n" "ANI_REFSEQ" "FAILED" "/ANI/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	#status="FAILED"
 fi

 #Check c-SSTAR
 if [[ -d "${OUTDATADIR}/c-sstar/" ]]; then
 	if [[ -z "${gapping}" ]]; then
 		gapping="gapped"
 	fi
 	if [[ -z "${sim}" ]]; then
 		sim="98"
 	fi
  for thing in ${OUTDATADIR}/c-sstar/*; do
    if [[ ${thing} = *${sample_name}.ResGANNCBI*.${gapping}_${sim}_sstar_summary.txt ]]; then
      csstar_file=$(find ${OUTDATADIR}/c-sstar/${sample_name}.ResGANNCBI*.${gapping}_${sim}_sstar_summary.txt -maxdepth 1 -type f -printf '%p\n' | sort -k2,2 -rt '_' -n | head -n 1)
      break
    fi
  done
  if [[ -z "${csstar_file}" ]]; then
 		printf "%-20s: %-8s : %s\\n" "c-SSTAR" "FAILED" "/c-sstar/ does not have an sstar_summary file"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	else
 		header=$(head -n1 "${csstar_file}")
 		ResGANNCBI_DB=$(echo "${csstar_file}" | rev | cut -d'.' -f3 | rev)
 		#echo "${ResGANNCBI_DB} = ${ResGANNCBI_srst2_filename} ?"
 		if [[ ${header} = *"No anti-microbial genes were found"* ]]; then
 			if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 				printf "%-20s: %-8s : %s\\n" "c-SSTAR" "ALERT" "Completed, but NO KNOWN AMR genes were found in ${ResGANNCBI_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "c-SSTAR" "ALERT" "Completed, but NO KNOWN AMR genes were found in ${ResGANNCBI_DB} (DB NOT up to date! Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		elif [[ ${header} = "No Assembly found to run c-sstar with" ]]; then
 			printf "%-20s: %-8s : %s\\n" "c-SSTAR" "FAILED" "No Assembly file to run through c-sstar"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		else
 			amr_genes_found=$(wc -l "${csstar_file}" | cut -d' ' -f1)
 			# Prints out the counts of AR gene hits
 			if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 				printf "%-20s: %-8s : %s\\n" "c-SSTAR" "SUCCESS" "${amr_genes_found} genes found in ${ResGANNCBI_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "c-SSTAR" "ALERT" "${amr_genes_found} genes found in ${ResGANNCBI_DB} (DB NOT up to date, Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		fi
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "c-SSTAR" "FAILED" "/c-sstar/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 #Check GAMA
 if [[ -d "${OUTDATADIR}/GAMA/" ]]; then
 	GAMA_file=$(find ${OUTDATADIR}/GAMA -maxdepth 1 -type f -name "${sample_name}.ResGANNCBI*.GAMA"   -printf '%p\n' | sort -k2,2 -rt '_' -n | head -n 1)
 	if [[ -z "${GAMA_file}" ]]; then
 		printf "%-20s: %-8s : %s\\n" "GAMA" "FAILED" "/GAMA/ does not have a .GAMA file"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	else
 		ResGANNCBI_DB=$(echo "${GAMA_file}" | rev | cut -d'.' -f2 | rev)
 		#echo "${ResGANNCBI_DB} = ${ResGANNCBI_srst2_filename} ?"
 		amr_genes_found=$(wc -l "${GAMA_file}" | cut -d' ' -f1)
 		amr_genes_found=$(( amr_genes_found - 1))
 		if [[ ${amr_genes_found} -le 0 ]]; then
 			if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 				printf "%-20s: %-8s : %s\\n" "GAMA" "ALERT" "Completed, but NO KNOWN AMR genes were found in ${ResGANNCBI_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "GAMA" "ALERT" "Completed, but NO KNOWN AMR genes were found in ${ResGANNCBI_DB} (DB NOT up to date! Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		else
 			# Prints out the counts of AR gene hits
 			if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 				printf "%-20s: %-8s : %s\\n" "GAMA" "SUCCESS" "${amr_genes_found} genes found in ${ResGANNCBI_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "GAMA" "ALERT" "${amr_genes_found} genes found in ${ResGANNCBI_DB} (DB NOT up to date, Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		fi
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "GAMA" "FAILED" "/GAMA/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 if [[ "${run_type}" == "all" ]]; then
 	# check SRST2 output
 	if [[ -d "${OUTDATADIR}/srst2/" ]]; then
    for thing in ${OUTDATADIR}/srst2/*; do
      if [[ "${thing}" = *${sample_name}__genes__ResGANNCBI*_srst2__results.txt ]]; then
        ResGANNCBI_srst2_file=$(find ${OUTDATADIR}/srst2/${sample_name}__genes__ResGANNCBI*_srst2__results.txt -maxdepth 1 -type f -printf '%p\n' | sort -k6,6 -rt '_' -n | head -n 1)
        break
      fi
    done
 		#echo ${ResGANNCBI_srst2_file}
 		if [[ -s "${ResGANNCBI_srst2_file}" ]]; then
 			ResGANNCBI_srst2_DB=$(echo "${ResGANNCBI_srst2_file}" | rev | cut -d'_' -f4,5 | rev)
 			info_ResGANNCBI_List=$(head -n 1 "${ResGANNCBI_srst2_file}")
 			IFS='	' read -r -a ResGANNCBI_array <<< "${info_ResGANNCBI_List}"
 			ResGANNCBI_Num="${#ResGANNCBI_array[@]}"
 			ResGANNCBI_Num=$(( ResGANNCBI_Num - 1 ))
 			#echo "${info_ResGANNCBI_List} - ${ResGANNCBI_Num}"
 			if [[ "${ResGANNCBI_Num}" -eq 0 ]]; then
 				if [[ "${ResGANNCBI_srst2_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 					printf "%-20s: %-8s : %s\\n" "srst2" "ALERT" "Completed, but NO KNOWN AMR genes present from ${ResGANNCBI_srst2_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					if [[ "${status}" == "SUCCESS" ]]; then
 						status="ALERT"
 					fi
 				else
 					printf "%-20s: %-8s : %s\\n" "srst2" "ALERT" "Completed, but NO KNOWN AMR genes present from ${ResGANNCBI_srst2_DB} (DB NOT up to date! Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					if [[ "${status}" == "SUCCESS" ]]; then
 						status="ALERT"
 					fi
 				fi
 			else
 				if [[ "${ResGANNCBI_srst2_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 					printf "%-20s: %-8s : %s\\n" "srst2" "SUCCESS" "${ResGANNCBI_Num} genes found in ${ResGANNCBI_srst2_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				else
 					printf "%-20s: %-8s : %s\\n" "srst2" "ALERT" "${ResGANNCBI_Num} genes found in ${ResGANNCBI_srst2_DB} (DB NOT up to date! Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					if [[ "${status}" == "SUCCESS" ]]; then
 						status="ALERT"
 					fi
 				fi
 			fi
 		else
 			printf "%-20s: %-8s : %s\\n" "srst2" "FAILED" "genes file does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "srst2" "FAILED" "/srst2/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "srst2" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 fi

 # check MLST
 if [[ -d "${OUTDATADIR}/MLST/" ]]; then
 	#if [[ -s "${OUTDATADIR}/MLST/${sample_name}_Pasteur.mlst" ]] || [[ -s "${OUTDATADIR}/MLST/${sample_name}_pubMLST.mlst" ]] || [[ -s "${OUTDATADIR}/MLST/${sample_name}.mlst" ]] || [[ -s "${OUTDATADIR}/MLST/${sample_name}_Mycobacterium.mlst" ]]; then
 		if [[ -f "${OUTDATADIR}/MLST/${sample_name}.mlst" ]]; then
      tmp_db=$(echo "${info}" | cut -d'	' -f2)
 			mv "${OUTDATADIR}/MLST/${sample_name}.mlst" "${OUTDATADIR}/MLST/${sample_name}_${tmp_db}.mlst"
 		fi
 		if [[ -f "${OUTDATADIR}/MLST/${sample_name}_ecoli_2.mlst" ]]; then
 			mv "${OUTDATADIR}/MLST/${sample_name}_Pasteur.mlst" "${OUTDATADIR}/MLST/${sample_name}_Achtman.mlst"
 			mv "${OUTDATADIR}/MLST/${sample_name}_ecoli_2.mlst" "${OUTDATADIR}/MLST/${sample_name}_Pasteur.mlst"
 		fi
    # if [[ -f "${OUTDATADIR}/MLST/${sample_name}_pubMLST.mlst" ]]; then
    #   primary_mlst_file="${OUTDATADIR}/MLST/${sample_name}_pubMLST.mlst"
    # elif [[ -f "${OUTDATADIR}/MLST/${sample_name}_Pasteur.mlst" ]]; then
    #   primary_mlst_file="${OUTDATADIR}/MLST/${sample_name}_Pasteur.mlst"
    # elif [[ -f "${OUTDATADIR}/MLST/${sample_name}_Mycobacterium.mlst" ]]; then
    #   primary_mlst_file="${OUTDATADIR}/MLST/${sample_name}_Mycobacterium.mlst"
    # else
    #   echo "Should never get here, but check just in case"
    # fi
 		# info=$(head -n 1 "${primary_mlst_file}")
 		# mlstype=$(echo "${info}" | cut -d'	' -f3)
    # mlstdb=$(echo "${info}" | cut -d'	' -f2)
 		# mlstdb_filelabel=$(echo "${primary_mlst_file}" | rev | cut -d'.' -f2 | cut -d'_' -f1 | rev)

    primary_mlst_file=""
		for mlst_file in ${OUTDATADIR}/MLST/*.mlst; do
			if [[ ${mlst_file} = *"${sample_name}_Pasteur.mlst" ]] || [[ ${mlst_file} = *"${sample_name}_Mycobacterium.mlst" ]]; then
				primary_mlst_file=${mlst_file}
				break
			elif [[ ${mlst_file} = *"${sample_name}_srst2_"* ]] || [[ ${mlst_file} = *"${sample_name}_Oxford.mlst" ]] || [[ ${mlst_file} = *"${sample_name}_Achtman.mlst" ]] || [[ ${mlst_file} = *"${sample_name}_mabscessus.mlst" ]]; then
				:
			elif [[ ${mlst_file} = *"${sample_name}_Unassigned.mlst" ]]; then
				primary_mlst_file="unassigned"
				break
			else
				temp_DB=$(head -n1 ${mlst_file} | cut -d'	' -f2)
				if [[ ${mlst_file} = *"${sample_name}_${temp_DB}.mlst" ]]; then
					primary_mlst_file=${mlst_file}
					break
				fi
			fi
		done

    if [[ "${primary_mlst_file}" = "unassigned" ]]; then
      printf "%-20s: %-8s : %s\\n" "MLST" "FAILED" "no scheme found, check if genus/species exists in MLST DB"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
    elif [[ -n "${primary_mlst_file}" ]]; then
      info=$(head -n 1 "${primary_mlst_file}")
   		mlstype=$(echo "${info}" | cut -d'	' -f3)
      mlstdb=$(echo "${info}" | cut -d'	' -f2)
   		mlstdb_filelabel=$(echo "${primary_mlst_file}" | rev | cut -d'.' -f2 | cut -d'_' -f1 | rev)
   		if [ "${mlstdb}" = "-" ]; then
   			if [ "${dec_genus}" ] && [ "${dec_species}" ]; then
   				printf "%-20s: %-8s : %s\\n" "MLST" "ALERT" "no scheme found, check pubmlst for ${dec_genus} ${dec_species}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   				if [[ "${status}" = "SUCCESS" ]]; then
   					status="WARNING"
   				fi
   			else
   				printf "%-20s: %-8s : %s\\n" "MLST" "FAILED" "no scheme found, check upstream as no genus/species has been assigned"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   			fi
   		elif [ "${mlstype}" = "-" ] || [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ]; then
   			printf "%-20s: %-8s : %s\\n" "MLST_${mlstdb_filelabel}" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   			report_info=$(echo "${info}" | cut -d' ' -f2-)
   			if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   				status="WARNING"
   			fi
   		elif [ "${mlstype}" = "AU" ]; then
   			printf "%-20s: %-8s : %s\\n" "MLST_${mlstdb_filelabel}" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}(${mlstdb_filelabel})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   			status="FAILED"
   		else
   			printf "%-20s: %-8s : %s\\n" "MLST_${mlstdb_filelabel}" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}(${mlstdb_filelabel})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   		fi
 	  else
 		   printf "%-20s: %-8s : %s\\n" "MLST_${mlstdb_filelabel}" "FAILED" "${sample_name}_${mlstdb_filelabel}.mlst does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		   status="FAILED"
 	  fi
   	if [[ "${dec_genus}" = "Acinetobacter" ]]; then
   		if [[ -s "${OUTDATADIR}/MLST/${sample_name}_abaumannii.mlst" ]] || [[ -s "${OUTDATADIR}/MLST/${sample_name}_Oxford.mlst" ]]; then
   			if [[ -s "${OUTDATADIR}/MLST/${sample_name}_abaumannii.mlst" ]]; then
   				mv "${OUTDATADIR}/MLST/${sample_name}_abaumannii.mlst" "${OUTDATADIR}/MLST/${sample_name}_Oxford.mlst"
   			fi
   			info=$(tail -n 1 "${OUTDATADIR}/MLST/${sample_name}_Oxford.mlst")
   			mlstype=$(echo "${info}" | cut -d'	' -f3)
   			mlstdb=$(echo "${info}" | cut -d'	' -f2)
   			#echo "'${mlstdb}:${mlstype}'"
   			if [ "${mlstdb}" = "abaumannii" ]; then
   				if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
   					printf "%-20s: %-8s : %s\\n" "MLST_OX" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					report_info=$(echo "${info}" | cut -d' ' -f2-)
   					if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   						status="WARNING"
   					fi
   				elif [ "${mlstype}" = "AU" ]; then
   					printf "%-20s: %-8s : %s\\n" "MLST_OX" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}(Oxford)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					status="FAILED"
   				else
   					printf "%-20s: %-8s : %s\\n" "MLST_OX" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}(Oxford)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   				fi
   			else
   				echo "Not reporting as name and analyis expected do not match"
   			fi
      else
        printf "%-20s: %-8s : %s\\n" "MLST_OX" "FAILED" "${sample_name}_Oxford.mlst does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   		fi
    elif [[ "${dec_genus}" = "Escherichia" ]]; then
   		if [[ -s "${OUTDATADIR}/MLST/${sample_name}_Achtman.mlst" ]]; then
   			info=$(tail -n 1 "${OUTDATADIR}/MLST/${sample_name}_Achtman.mlst")
   			mlstype=$(echo "${info}" | cut -d'	' -f3)
   			mlstdb=$(echo "${info}" | cut -d'	' -f2)
   			#echo "'${mlstdb}:${mlstype}'"
   			if [ "${mlstdb}" = "ecoli" ]; then
   				if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
   					printf "%-20s: %-8s : %s\\n" "MLST_ACHT" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					report_info=$(echo "${info}" | cut -d' ' -f2-)
   					if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   						status="WARNING"
   					fi
   				elif [ "${mlstype}" = "AU" ]; then
   					printf "%-20s: %-8s : %s\\n" "MLST_ACHT" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}(Achtman)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					status="FAILED"
   				else
   					printf "%-20s: %-8s : %s\\n" "MLST_ACHT" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}(Achtman)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   				fi
   			else
   				echo "Not reporting as name and analyis expected do not match"
   			fi
      else
        printf "%-20s: %-8s : %s\\n" "MLST_ACHT" "FAILED" "${sample_name}_Achtman.mlst does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   		fi
   	elif [[ "${dec_genus}" = "Mycobacterium" ]] || [[ "${dec_genus}" = "Mycobacteroides" ]] || [[ "${dec_genus}" = "Mycolicibacterium" ]]; then
   		if [[ -s "${OUTDATADIR}/MLST/${sample_name}_mabscessus.mlst" ]]; then
   			info=$(tail -n 1 "${OUTDATADIR}/MLST/${sample_name}_mabscessus.mlst")
   			mlstype=$(echo "${info}" | cut -d'	' -f3)
   			mlstdb=$(echo "${info}" | cut -d'	' -f2)
   			#echo "'${mlstdb}:${mlstype}'"
   			if [ "${mlstdb}" = "mabscessus" ]; then
   				if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
   					printf "%-20s: %-8s : %s\\n" "MLST_MAB" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					report_info=$(echo "${info}" | cut -d' ' -f2-)
   					if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   						status="WARNING"
   					fi
   				elif [ "${mlstype}" = "AU" ]; then
   					printf "%-20s: %-8s : %s\\n" "MLST_MAB" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}(Mabscessus)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					status="FAILED"
   				else
   					printf "%-20s: %-8s : %s\\n" "MLST_MAB" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}(Mabscessus)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   				fi
   			else
   				echo "Not reporting as name and analyis expected do not match"
   			fi
      else
        printf "%-20s: %-8s : %s\\n" "MLST_MAB" "FAILED" "${sample_name}_mabscessus.mlst does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   		fi
 	  fi
  else
    printf "%-20s: %-8s : %s\\n" "MLST" "FAILED" "${OUTDATADIR}/${sample_name}/MLST does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
    status="FAILED"
  fi

 	if [[ "${run_type}" == "all" ]]; then
 		# Check srst2 MLSTs
 		num_srst2_mlsts=$(find ${OUTDATADIR}/MLST -type f -name "*_srst2_*.mlst" | wc -l)
 		#echo "${num_srst2_mlsts}"
 		if [[ "${num_srst2_mlsts}" -eq 0 ]]; then
 			#echo "No mlst srst2 was attempted on this isolate (${sample_name})"
 			:
    else
      for srst2_mlst in "${OUTDATADIR}/MLST/*_srst2_*.mlst"; do
        if [[ "${srst_mlst}" == *"-Standard.mlst" ]]; then
   				new_srst_mlst=${srst_mlst/Standard/pubMLST}
   				mv ${srst_mlst} ${new_srst_mlst}
   				srst_mlst=${new_srst_mlst}
   			fi
 				if [[ "${dec_genus}" = "Acinetobacter" ]]; then
   				if [[ "${srst_mlst}" = "${OUTDATADIR}/MLST/${sample_name}_srst2_Acinetobacter_baumannii#1-Oxford.mlst" ]]; then
   					mlstype=$(tail -n1 ${srst_mlst} | cut -d'	' -f2)
   					mlstdb="abaumannii(Oxford)"
   					if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Oxford" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						report_info=$(echo "${info}" | cut -d' ' -f2-)
   						if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   							status="WARNING"
   						fi
   					elif [ "${mlstype}" = "AU" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2(Oxford)" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						status="FAILED"
   					else
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2(Oxford)" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					fi
   				elif [[ "${srst2_mlst}" = "${OUTDATADIR}/MLST/${sample_name}_srst2_Acinetobacter_baumannii#2-Pasteur.mlst" ]]; then
   					mlstype=$(tail -n1 ${srst_mlst} | cut -d'	' -f2)
   					mlstdb="abaumannii_2(Pasteur)"
   					if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Pasteur" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						report_info=$(echo "${info}" | cut -d' ' -f2-)
   						if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   							status="WARNING"
   						fi
   					elif [ "${mlstype}" = "AU" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Pasteur" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						status="FAILED"
   					else
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Pasteur" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					fi
          else
            printf "%-20s: %-8s : %s\\n" "MLST-srst2" "ALERT" "Unknown srst2 file found ${srst_mlst}, expecting ${OUTDATADIR}/MLST/${sample_name}_srst2_Acinetobacter_baumannii#[1|2]-Pasteur.mlst"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   				fi
        elif [[ "${dec_genus}" = "Escherichia" ]]; then
   				if [[ "${srst_mlst}" = "${OUTDATADIR}/MLST/${sample_name}_srst2_Escherichia_coli#1-Achtman.mlst" ]]; then
   					mlstype=$(tail -n1 ${srst_mlst} | cut -d'	' -f2)
   					mlstdb="ecoli(Achtman)"
   					if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Achtman" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						report_info=$(echo "${info}" | cut -d' ' -f2-)
   						if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   							status="WARNING"
   						fi
   					elif [ "${mlstype}" = "AU" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Achtman" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						status="FAILED"
   					else
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Achtman" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					fi
   				elif [[ "${srst_mlst}" = "${OUTDATADIR}/MLST/${sample_name}_srst2_Escherichia_coli#2-Pasteur.mlst" ]]; then
   					mlstype=$(tail -n1 ${srst_mlst} | cut -d'	' -f2)
   					mlstdb="ecoli_2(Pasteur)"
   					if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Pasteur" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						report_info=$(echo "${info}" | cut -d' ' -f2-)
   						if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
   							status="WARNING"
   						fi
   					elif [ "${mlstype}" = "AU" ]; then
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Pasteur" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   						status="FAILED"
   					else
   						printf "%-20s: %-8s : %s\\n" "MLST-srst2_Pasteur" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   					fi
          else
            printf "%-20s: %-8s : %s\\n" "MLST-srst2" "ALERT" "Unknown srst2 file found ${srst_mlst}, expecting ${OUTDATADIR}/MLST/${sample_name}_srst2_Escherichia_coli#[1|2]-Pasteur.mlst"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   				fi
        elif [[ "${dec_genus}" = "Mycobacterium" ]] || [[ "${dec_genus}" = "Mycobacteroides" ]] || [[ "${dec_genus}" = "Mycolicibacterium" ]]; then
          if [[ "${srst_mlst}" =  "${OUTDATADIR}/MLST/${sample_name}_srst2_Mycobacterium_spp.-Mycobacterium.mlst" ]]; then
            mlstype=$(tail -n1 ${srst_mlst} | cut -d'	' -f2)
            mlstdb="Mycobacterium(Mycobacterium)"
            if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
              printf "%-20s: %-8s : %s\\n" "MLST-srst2_Mycobacterium" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
              report_info=$(echo "${info}" | cut -d' ' -f2-)
              if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
                status="WARNING"
              fi
            elif [ "${mlstype}" = "AU" ]; then
              printf "%-20s: %-8s : %s\\n" "MLST-srst2_Mycobacterium" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
              status="FAILED"
            else
              printf "%-20s: %-8s : %s\\n" "MLST-srst2_Mycobacterium" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
            fi
          elif [[ "${srst_mlst}" = "${OUTDATADIR}/MLST/${sample_name}_srst2_Mycobacteroides_abscessus-Mabscsessus.mlst" ]]; then
            mlstype=$(tail -n1 ${srst_mlst} | cut -d'	' -f2)
            mlstdb="Mabscessus(Mabscessus)"
            if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
              printf "%-20s: %-8s : %s\\n" "MLST-srst2_Mabscessus" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
              report_info=$(echo "${info}" | cut -d' ' -f2-)
              if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
                status="WARNING"
              fi
            elif [ "${mlstype}" = "AU" ]; then
              printf "%-20s: %-8s : %s\\n" "MLST-srst2_Mabscessus" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
              status="FAILED"
            else
              printf "%-20s: %-8s : %s\\n" "MLST-srst2_Mabscessus" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
            fi
          fi
        else
          mlstype=$(tail -n1 ${srst_mlst} | cut -d'	' -f2)
     			mlstdb=$(echo "${srst_mlst}" | rev | cut -d'-' -f2 | cut -d'_' -f1,2 | rev )
          mlstdb_filelabel=$(echo "${srst_mlst}" | rev | cut -d'-' -f1 | cut -d'.' -f2 | rev )
     			if [ "${mlstype}" = "A-SUB" ] || [ "${mlstype}" = "P-SUB" ] || [ "${mlstype}" = "-" ]; then
     				printf "%-20s: %-8s : %s\\n" "MLST-srst2_${mlstdb_filelabel}" "WARNING" "No type found, possibly new type?"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
     				report_info=$(echo "${info}" | cut -d' ' -f2-)
     				if [[ "${status}" = "SUCCESS" ]] || [[ "${status}" = "ALERT" ]]; then
     					status="WARNING"
     				fi
     			elif [ "${mlstype}" = "AU" ]; then
     				printf "%-20s: %-8s : %s\\n" "MLST-srst2_${mlstdb_filelabel}" "FAILED" "1+ allele is missing, cant determine ST type in ${mlstdb}(${mlstdb_filelabel})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
     				status="FAILED"
     			else
     				printf "%-20s: %-8s : %s\\n" "MLST-srst2_${mlstdb_filelabel}" "SUCCESS" "TYPE is ${mlstype} from ${mlstdb}(${mlstdb_filelabel})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
     			fi
        fi
      done
    fi
  fi

 # check 16s Identification
 if [[ -d "${OUTDATADIR}/16s/" ]]; then
 	if [[ -s "${OUTDATADIR}/16s/${sample_name}_16s_blast_id.txt" ]]; then
 		info_b=$(head -n 1 "${OUTDATADIR}/16s/${sample_name}_16s_blast_id.txt")
 		genus_b=$(echo ${info_b} | cut -d' ' -f3)
 		species_b=$(echo ${info_b} | cut -d' ' -f4-)
 		IFS=' ' read -r -a id_array <<< "${info_b}"
 		if [ ${#id_array[@]} -gt 3 ]; then
 			extra_b="${id_array[@]:3:}"
 		else
 			extra_b=""
 		fi
 		#echo "g-${genus_b},s-${species_b}"
 		if [ ! -z "${genus_b}" ] && [ ! -z "${species_b}" ]; then
      if [[ "${genus_b}" == "FAILED" ]] && [[ "${species_b}" == "TIMEOUT" ]]; then
				printf "%-20s: %-8s : %s\\n" "16s_best_Remote" "Warning" "NCBI -remote request timed out, try again or do manually" >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
				if [ "$status" = "SUCCESS" ]; then
					status="Warning"
				fi
			else
        printf "%-20s: %-8s : %s\\n" "16s_best_Remote" "SUCCESS" "${genus_b} ${species_b} ${extra_b}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
      fi
 		elif [ -z "${species_b}" ]; then
 			if [ "${genus_b}" = "No_16s_sequences_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_best_Remote" "FAILED" "No 16s sequences found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			elif [ "${genus_b}" = "No_16s_matches_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_best_Remote" "FAILED" "16s sequences were found but were not able to be classified"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			else
 				printf "%-20s: %-8s : %s\\n" "16s_best_Remote" "Warning" "Genus=${genus_b}, but no species found,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "$status" = "SUCCESS" ]; then
 					status="Warning"
 				fi
 			fi

 		elif [ -z "${genus_b}" ]; then
 			printf "%-20s: %-8s : %s\\n" "16s_best_Remote" "FAILED" "No genus found,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_b}" | cut -d' ' -f2-)
 			status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "16s_best_Remote" "FAILED" "Nothing found in ${sample_name}_16s_blast_id.txt,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_l}" | cut -d' ' -f2-)
 			status="FAILED"
 		fi
 		info_l=$(tail -n 1 "${OUTDATADIR}/16s/${sample_name}_16s_blast_id.txt")
 		genus_l=$(echo ${info_l} | cut -d' ' -f3)
 		species_l=$(echo ${info_l} | cut -d' ' -f4-)
 		IFS=' ' read -r -a id_array <<< "${info_l}"
 		if [ ${#id_array[@]} -gt 3 ]; then
 			extra_l="${id_array[@]:3:}"
 		else
 			extra_l=""
 		fi
 		if [ ! -z "${genus_l}" ] && [ ! -z "${species_l}" ]; then
      if [[ "${genus_l}" == "FAILED" ]] && [[ "${species_l}" == "TIMEOUT" ]]; then
				printf "%-20s: %-8s : %s\\n" "16s_largest_Remote" "Warning" "NCBI -remote request timed out, try again or do manually" >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
				if [ "$status" = "SUCCESS" ]; then
					status="Warning"
				fi
			else
        printf "%-20s: %-8s : %s\\n" "16s_largest_Remote" "SUCCESS" "${genus_l} ${species_l} ${extra_l}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
      fi
 		elif [ -z "${species_l}" ]; then
 			if [ "${genus_l}" = "No_16s_sequences_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_largest_Remote" "FAILED" "No 16s sequences found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			elif [ "${genus_l}" = "No_16s_matches_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_largest_Remote" "FAILED" "16s sequences were found but were not able to be classified"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			else
 				printf "%-20s: %-8s : %s\\n" "16s_largest_Remote" "Warning" "Genus=${genus_l}, but no species found,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "$status" = "SUCCESS" ]; then
 					status="Warning"
 				fi
 			fi
 		elif [ -z "${genus_l}" ]; then
 			printf "%-20s: %-8s : %s\\n" "16s_largest_Remote" "FAILED" "no genus found,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_l}" | cut -d' ' -f2-)
 			status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "16s_largest_Remote" "FAILED" "nothing found in ${sample_name}_16s_blast_id.txt,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_l}" | cut -d' ' -f2-)
 			status="FAILED"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "16s Remote" "FAILED" "${sample_name}_16s_blast_id.txt does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 # No 16s folder exists (pipeline must have failed as it would create a default one otherwise)
 else
 	printf "%-20s: %-8s : %s\\n" "16s Remote" "FAILED" "/16s/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 # check 16s LOCAL Identification
 if [[ -d "${OUTDATADIR}/16s/" ]]; then
  underscore_index=$(( sample_name_underscore_count + 6 ))
  newest_16s_local=$(find ${OUTDATADIR}/16s/ -maxdepth 1 -type f -name "${sample_name}_16s_blast_id_local_*.txt" | sort -k${underscore_index},${underscore_index} -rt '_' -n | head -n1)
 	if [[ -s "${newest_16s_local}" ]]; then
    short_16s_filename=$(echo "${newest_16s_local}" | rev | cut -d"/" -f1 | rev)
 		info_b=$(head -n 1 "${newest_16s_local}")
 		genus_b=$(echo ${info_b} | cut -d' ' -f3)
 		species_b=$(echo ${info_b} | cut -d' ' -f4-)
 		IFS=' ' read -r -a id_array <<< "${info_b}"
 		if [ ${#id_array[@]} -gt 3 ]; then
 			extra_b="${id_array[@]:3:}"
 		else
 			extra_b=""
 		fi
 		#echo "g-${genus_b},s-${species_b}"
 		if [ ! -z "${genus_b}" ] && [ ! -z "${species_b}" ]; then
      printf "%-20s: %-8s : %s\\n" "16s_best_SCICOMP" "SUCCESS" "${genus_b} ${species_b} ${extra_b}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		elif [ -z "${species_b}" ]; then
 			if [ "${genus_b}" = "No_16s_sequences_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_best_SCICOMP" "FAILED" "No 16s sequences found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			elif [ "${genus_b}" = "No_16s_matches_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_best_SCICOMP" "FAILED" "16s sequences were found but were not able to be classified"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			else
 				printf "%-20s: %-8s : %s\\n" "16s_best_SCICOMP" "Warning" "Genus=${genus_b}, but no species found,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "$status" = "SUCCESS" ]; then
 					status="Warning"
 				fi
 			fi

 		elif [ -z "${genus_b}" ]; then
 			printf "%-20s: %-8s : %s\\n" "16s_best_SCICOMP" "FAILED" "No genus found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_b}" | cut -d' ' -f2-)
 			status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "16s_best_SCICOMP" "FAILED" "Nothing found in ${short_16s_filename}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_l}" | cut -d' ' -f2-)
 			status="FAILED"
 		fi
 		info_l=$(tail -n 1 "${newest_16s_local}")
 		genus_l=$(echo ${info_l} | cut -d' ' -f3)
 		species_l=$(echo ${info_l} | cut -d' ' -f4-)
 		IFS=' ' read -r -a id_array <<< "${info_l}"
 		if [ ${#id_array[@]} -gt 3 ]; then
 			extra_l="${id_array[@]:3:}"
 		else
 			extra_l=""
 		fi
 		if [ ! -z "${genus_l}" ] && [ ! -z "${species_l}" ]; then
      printf "%-20s: %-8s : %s\\n" "16s_largest_SCICOMP" "SUCCESS" "${genus_l} ${species_l} ${extra_l}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		elif [ -z "${species_l}" ]; then
 			if [ "${genus_l}" = "No_16s_sequences_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_largest_SCICOMP" "FAILED" "No 16s sequences found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			elif [ "${genus_l}" = "No_16s_matches_found" ]; then
 				printf "%-20s: %-8s : %s\\n" "16s_largest_SCICOMP" "FAILED" "16s sequences were found but were not able to be classified"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			else
 				printf "%-20s: %-8s : %s\\n" "16s_largest_SCICOMP" "Warning" "Genus=${genus_l}, but no species found,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				if [ "$status" = "SUCCESS" ] || [ "$status" = "ALERT" ]; then
 					status="Warning"
 				fi
 			fi
 		elif [ -z "${genus_l}" ]; then
 			printf "%-20s: %-8s : %s\\n" "16s_largest_SCICOMP" "FAILED" "no genus found,"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_l}" | cut -d' ' -f2-)
 			status="FAILED"
 		else
 			printf "%-20s: %-8s : %s\\n" "16s_largest_SCICOMP" "FAILED" "nothing found in ${short_16s_filename}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			report_info=$(echo "${info_l}" | cut -d' ' -f2-)
 			status="FAILED"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "16s_Local_Scicomp" "ALERT" "/${OUTDATADIR}/${sample_name}/16s/${sample_name}_16s_blast_id_local_*.txt does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
    if [ "$status" = "SUCCESS" ]; then
      status="ALERT"
    fi
 	fi
 # No 16s folder exists (pipeline must have failed as it would create a default one otherwise)
 else
 	printf "%-20s: %-8s : %s\\n" "16s Local Scicomp" "FAILED" "/16s/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 # # check plasmids
 # if [[ -d "${OUTDATADIR}/plasmidFinder/" ]]; then
 # 	if [[ -s "${OUTDATADIR}/plasmidFinder/${sample_name}_results_table_summary.txt" ]]; then
 # 		number_of_plasmids=0
 # 		while read line_in; do
 # 			line_in=$(echo ${line_in} | cut -d' ' -f1)
 # 			if [[ "${line_in}" = "No" ]] || [[ "${line_in}" = "Enterococcus,Streptococcus,Staphylococcus" ]] || [[ "${line_in}" = "Enterobacteriaceae" ]] || [[ "${line_in}" = "Plasmid" ]]; then
 # 				:
 # 			else
 # 				number_of_plasmids=$(( number_of_plasmids + 1 ))
 # 			fi
 # 		done < "${OUTDATADIR}/plasmidFinder/${sample_name}_results_table_summary.txt"
 # 		if [[ ${number_of_plasmids} -eq 1 ]]; then
 # 			printf "%-20s: %-8s : %s\\n" "plasmidFinder" "SUCCESS" "${number_of_plasmids} replicon was found in the full scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 # 		elif [[ ${number_of_plasmids} -gt 1 ]]; then
 # 			printf "%-20s: %-8s : %s\\n" "plasmidFinder" "SUCCESS" "${number_of_plasmids} replicons were found in the full scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 # 		else
 # 			printf "%-20s: %-8s : %s\\n" "plasmidFinder" "SUCCESS" "No replicons were found in the full scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 # 		fi
 # 	else
 # 		printf "%-20s: %-8s : %s\\n" "plasmidFinder" "FAILED" "results_table_summary.txt does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 # 		status="FAILED"
 # 	fi
 # # No plasmid folder exists
 # else
 # 	printf "%-20s: %-8s : %s\\n" "plasmidFinder" "FAILED" "/plasmidFinder/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 # 	status="FAILED"
 # fi

 # check HV
 Rep_genes="NA"
 if [[ -d "${OUTDATADIR}/GAMA/" ]]; then
 	if [[ -s "${OUTDATADIR}/GAMA/${sample_name}.${Replicon_Date_and_Version}.GAMA.gamma" ]]; then
 		Rep_genes=0
 		while read line_in; do
      if [[ "${line_in}" = "Gene	Contig	Start	Stop	Match_Type"* ]]; then
 				:
 			else
 				Rep_genes=$(( Rep_genes + 1 ))
 			fi
 		done < "${OUTDATADIR}/GAMA/${sample_name}.${Replicon_Date_and_Version}.GAMA.gamma"

    if [[ ${Rep_genes} -eq 0 ]]; then
      printf "%-20s: %-8s : %s\\n" "Plsmd Replicons-GAMA" "SUCCESS" "No replicons were found in the full scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
    elif [[ ${Rep_genes} -ge 1 ]]; then
 			printf "%-20s: %-8s : %s\\n" "Plsmd Replicons-GAMA" "SUCCESS" "${Rep_genes} replicon(s) found in the full scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		else
      echo "Should never get here (Rep_genes less than 0)"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "Plsmd Replicons-GAMA" "FAILED" "${Replicon_Date_and_Version}.GAMA.gamma does not exist (could just be out of date)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 # No plasmid folder exists
 else
 	printf "%-20s: %-8s : %s\\n" "Plsmd Replicons-GAMA" "FAILED" "/GAMA/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi

 # check HV
 HV_genes="NA"
 if [[ -d "${OUTDATADIR}/GAMA/" ]]; then
 	if [[ -s "${OUTDATADIR}/GAMA/${sample_name}.${HV_Date_and_Version}.GAMA.gamma" ]]; then
 		HV_genes=0
 		while read line_in; do
 			if [[ "${line_in}" = "Gene	Contig	Start	Stop	Match_Type"* ]]; then
 				:
 			else
 				HV_genes=$(( HV_genes + 1 ))
 			fi
 		done < "${OUTDATADIR}/GAMA/${sample_name}.${HV_Date_and_Version}.GAMA.gamma"

    if [[ ${HV_genes} -eq 0 ]]; then
      printf "%-20s: %-8s : %s\\n" "HyperVirulence" "SUCCESS" "No genes were found in the full scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
    elif [[ ${HV_genes} -ge 1 ]]; then
 			printf "%-20s: %-8s : %s\\n" "HyperVirulence" "SUCCESS" "${HV_genes} gene(s) found in the full scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		else
      echo "Should never get here (HV_genes less than 0)"
 		fi
 	else
 		printf "%-20s: %-8s : %s\\n" "HyperVirulence" "FAILED" "${HV_Date_and_Version}.GAMA.gamma does not exist (could just be out of date)"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	fi
 # No plasmid folder exists
 else
 	printf "%-20s: %-8s : %s\\n" "HyperVirulence" "FAILED" "/GAMA/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	status="FAILED"
 fi


 if [[ "${run_type}" == "all" ]]; then
 	# #Check plasFlow plasmid assembly
 	plasmidsFoundviaplasFlow=0
 	if [[ -d "${OUTDATADIR}/plasFlow" ]]; then
 		if [[ -s "${OUTDATADIR}/plasFlow/Unicycler_assemblies/${sample_name}_uni_assembly/${sample_name}_plasmid_assembly_original.fasta" ]]; then
 			# Count the number of '>' in the assembly file before trimming
 			plas_scaffolds=">"
 			plas_scaffolds=$(grep -c ${plas_scaffolds} "${OUTDATADIR}/plasFlow/Unicycler_assemblies/${sample_name}_uni_assembly/${sample_name}_plasmid_assembly_original.fasta")
 			if [ -z ${plas_scaffolds} ]; then
 				plas_scaffolds=0
 			fi
 			if [[ "${plas_scaffolds}" -gt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "plasFlow Assembly" "SUCCESS" "${plas_scaffolds} scaffolds found via plasFlow"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				plasmidsFoundviaplasFlow=1
 			#else
 			#	printf "%-20s: %-8s : %s\\n" "plasFlow Assembly" "ALERT" "No plasmid scaffold found?"
 			#	if [[ "${status}" == "SUCCESS" ]]; then
 			#		status="ALERT"
 			#	fi
 			fi
 		# Needs a better catch of if it ran and failed vs ran and succeeded but with nothing to find
 		else
 			printf "%-20s: %-8s : %s\\n" "plasFlow Assembly" "WARNING" "No plasmid scaffold found using plasFlow"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			if [[ "${status}" == "SUCCESS" ]] || [[ "${status}" == "ALERT" ]]; then
 				status="Warning"
 			fi
 		fi
 	elif [[ "${dec_family}" == "Enterobacteriaceae" ]]; then
 		printf "%-20s: %-8s : %s\\n" "plasFlow Assembly" "FAILED" "/plasFlow not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		status="FAILED"
 	else
 		printf "%-20s: %-8s : %s\\n" "plasFlow" "SUCCESS" "Not correct TAXA for plasFlow analysis"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 	fi

 	#Check short scaffolds reduction script for plasmid assembly
 	#echo "${plasmidsFoundviaplasFlow}-Found?"
 	if [[ "${plasmidsFoundviaplasFlow}" -eq 1 ]]; then
 		if [[ -s "${OUTDATADIR}/plasFlow/Unicycler_assemblies/${sample_name}_uni_assembly/${sample_name}_plasmid_assembly_trimmed.fasta" ]]; then
 			# Count the number of '>' still remaining after trimming the contig file
 			plas_longies=">"
 			plas_longies=$(grep -c ${plas_longies} "${OUTDATADIR}/plasFlow/Unicycler_assemblies/${sample_name}_uni_assembly/${sample_name}_plasmid_assembly_trimmed.fasta")
 			# Calculate the number of lost (short) scaffolds
 			plas_shorties=$(( plas_scaffolds - plas_longies ))
 			if [ -z ${plas_shorties} ]; then
 				plas_shorties=0
 			fi
 			if [[ "${plas_longies}" -gt 0 ]]; then
 				printf "%-20s: %-8s : %s\\n" "plasFlow contig Trim" "SUCCESS" "${plas_longies} scaffolds remain. ${plas_shorties} were removed due to shortness"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			else
 				printf "%-20s: %-8s : %s\\n" "plasFlow contig Trim" "SUCCESS" "No plasmid scaffold found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			fi
 		elif [[ -f "${OUTDATADIR}/plasFlow/Unicycler_assemblies/${sample_name}_uni_assembly/${sample_name}_plasmid_assembly_trimmed.fasta" ]]; then
 			printf "%-20s: %-8s : %s\\n" "plasFlow contig Trim" "SUCCESS" "No plasmid scaffolds found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		else
 			printf "%-20s: %-8s : %s\\n" "plasFlow contig Trim" "FAILED" "plasFlow/Unicycler_assemblies/${sample_name}_uni_assembly/${sample_name}_plasmid_assembly_trimmed.fasta not found"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		fi

 		# Check quality of plasmid Assembly
 		if [[ -s "${OUTDATADIR}/Assembly_Stats_plasFlow/${sample_name}_report.tsv" ]]; then
 			# Extract the useful bits and report (to compare to Toms)
 			contig_num_plas=$(sed -n '14p' "${OUTDATADIR}/Assembly_Stats_plasFlow/${sample_name}_report.tsv"| sed -r 's/[\t]+/ /g' | cut -d' ' -f3 )
 			assembly_length_plas=$(sed -n '16p' "${OUTDATADIR}/Assembly_Stats_plasFlow/${sample_name}_report.tsv" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3)
 			N50_plas=$(sed -n '18p' "${OUTDATADIR}/Assembly_Stats_plasFlow/${sample_name}_report.tsv"  | sed -r 's/[\t]+/ /g'| cut -d' ' -f2)
 			GC_con_plas=$(sed -n '17p' "${OUTDATADIR}/Assembly_Stats_plasFlow/${sample_name}_report.tsv" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3)
 			printf "%-20s: %-8s : %s\\n" "QUAST_plasFlow" "SUCCESS" "#-${contig_num_plas} length-${assembly_length_plas} n50-${N50_plas} %GC-${GC_con_plas}"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 		else
 			printf "%-20s: %-8s : %s\\n" "QUAST_plasFlow" "FAILED" "/Assembly_Stats_plasFlow/report.tsv does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		fi

 		#Check c-SSTAR of plasmid assembly
 		if [[ -d "${OUTDATADIR}/c-sstar_plasFlow/" ]]; then
 			if [[ -z "${gapping}" ]]; then
 				gapping="gapped"
 			fi
 			if [[ -z "${plasmid_sim}" ]]; then
 				plasmid_sim="40"
 			fi
 			csstar_plasFlow_file=$(find ${OUTDATADIR}/c-sstar_plasFlow/${sample_name}.ResGANNCBI*.${gapping}_${plasmid_sim}_sstar_summary.txt -maxdepth 1 -type f -printf '%p\n' | sort -k2,2 -rt '_' -n | head -n 1)
 			if [[ -z "${csstar_plasFlow_file}" ]]; then
 				printf "%-20s: %-8s : %s\\n" "c-SSTAR_plasFlow" "FAILED" "/c-sstar_plasFlow/ does not have an sstar_summary file"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				echo "Looking for ${OUTDATADIR}/c-sstar_plasFlow/${sample_name}.ResGANNCBI*.${gapping}_${plasmid_sim}_sstar_summary.txt"
 				status="FAILED"
 			else
 				header=$(head -n1 "${csstar_plasFlow_file}")
 				ResGANNCBI_DB=$(echo "${csstar_plasFlow_file}" | rev | cut -d'.' -f3 | rev)
 				if [[ ${header} = *"No anti-microbial genes were found"* ]]; then
 					if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 						printf "%-20s: %-8s : %s\\n" "c-SSTAR_plasFlow" "ALERT" "Completed, but NO KNOWN AMR genes present from ${ResGANNCBI_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 						if [[ "${status}" == "SUCCESS" ]]; then
 							status="ALERT"
 						fi
 					else
 						printf "%-20s: %-8s : %s\\n" "c-SSTAR_plasFlow" "ALERT" "Completed, but NO KNOWN AMR genes present from ${ResGANNCBI_DB} (DB NOT up to date! Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 						if [[ "${status}" == "SUCCESS" ]]; then
 							status="ALERT"
 						fi
 					fi
 				else
 					amr_genes_found=$(wc -l "${csstar_plasFlow_file}" | cut -d' ' -f1)
 					# Prints out the counts of AR gene hits
 					if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 						printf "%-20s: %-8s : %s\\n" "c-SSTAR_plasFlow" "SUCCESS" "${amr_genes_found} genes found in ${ResGANNCBI_DB} (%ID defaults to 40) (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					else
 						printf "%-20s: %-8s : %s\\n" "c-SSTAR_plasFlow" "ALERT" "${amr_genes_found} genes found in ${ResGANNCBI_DB} (%ID defaults to 40) (DB NOT up to date! Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 						if [[ "${status}" == "SUCCESS" ]]; then
 							status="ALERT"
 						fi
 					fi
 				fi
 			fi
 		else
 			printf "%-20s: %-8s : %s\\n" "c-sstar_plasFlow" "FAILED" "/c-sstar_plasFlow/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		fi

 		if [[ -d  "${OUTDATADIR}/GAMA_plasFlow" ]]; then
 			#Check c-SSTAR
 			GAMA_plasFlow_file=$(find ${OUTDATADIR}/GAMA_plasFlow -maxdepth 1 -type f -name "${sample_name}.ResGANNCBI*.GAMA"   -printf '%p\n' | sort -k2,2 -rt '_' -n | head -n 1)
 			if [[ -z "${GAMA_plasFlow_file}" ]]; then
 				printf "%-20s: %-8s : %s\\n" "GAMA_plasFlow" "FAILED" "/GAMA_plasFlow/ does not have a .GAMA file"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			else
 				ResGANNCBI_DB=$(echo "${GAMA_plasFlow_file}" | rev | cut -d'.' -f2 | rev)
 				#echo "${ResGANNCBI_DB} = ${ResGANNCBI_srst2_filename} ?"
 				plasmid_amr_genes_found=$(wc -l "${GAMA_plasFlow_file}" | cut -d' ' -f1)
 				plasmid_amr_genes_found=$(( plasmid_amr_genes_found - 1))
 				if [[ ${plasmid_amr_genes_found} -le 0 ]]; then
 					if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 						printf "%-20s: %-8s : %s\\n" "GAMA_plasFlow" "ALERT" "Completed, but NO KNOWN AMR genes were found in ${ResGANNCBI_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					else
 						printf "%-20s: %-8s : %s\\n" "GAMA_plasFlow" "ALERT" "Completed, but NO KNOWN AMR genes were found in ${ResGANNCBI_DB} (DB NOT up to date! Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					fi
 				else
 					# Prints out the counts of AR gene hits
 					if [[ "${ResGANNCBI_DB}" = "${ResGANNCBI_srst2_filename}" ]]; then
 						printf "%-20s: %-8s : %s\\n" "GAMA_plasFlow" "SUCCESS" "${plasmid_amr_genes_found} genes found in ${ResGANNCBI_DB} (DB up to date, as of ${today})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					else
 						printf "%-20s: %-8s : %s\\n" "GAMA_plasFlow" "ALERT" "${plasmid_amr_genes_found} genes found in ${ResGANNCBI_DB} (DB NOT up to date, Most current DB: ${ResGANNCBI_srst2_filename})"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 					fi
 				fi
 			fi
 		else
 			printf "%-20s: %-8s : %s\\n" "GAMA_plasFlow" "FAILED" "/GAMA_plasFlow/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		fi

 		# check plasmids (on plasmidAssembly)
 		if [[ -d "${OUTDATADIR}/plasmidFinder_on_plasFlow/" ]]; then
 			if [[ -s "${OUTDATADIR}/plasmidFinder_on_plasFlow/${sample_name}_results_table_summary.txt" ]]; then
 				number_of_plasmids=0
 				while read line_in; do
 					line_in=$(echo ${line_in} | cut -d' ' -f1)
 					if [[ "${line_in}" = "No" ]] || [[ "${line_in}" = "Enterococcus,Streptococcus,Staphylococcus" ]] || [[ "${line_in}" = "Enterobacteriaceae" ]] || [[ "${line_in}" = "Plasmid" ]]; then
 						:
 					else
 						number_of_plasmids=$(( number_of_plasmids + 1 ))
 					fi
 				done < "${OUTDATADIR}/plasmidFinder_on_plasFlow/${sample_name}_results_table_summary.txt"
 				if [[ ${number_of_plasmids} -eq 1 ]]; then
 					printf "%-20s: %-8s : %s\\n" "plasmidFndr-plasFlow" "SUCCESS" "${number_of_plasmids} replicon was found in the plasmid scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				elif [[ ${number_of_plasmids} -gt 1 ]]; then
 					printf "%-20s: %-8s : %s\\n" "plasmidFndr-plasFlow" "SUCCESS" "${number_of_plasmids} replicons were found in the plasmid scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				else
 					printf "%-20s: %-8s : %s\\n" "plasmidFndr-plasFlow" "SUCCESS" "No replicons were found in the plasmid scaffold"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				fi
 			else
 				printf "%-20s: %-8s : %s\\n" "plasmidFndr-plasFlow" "FAILED" "results_table_summary.txt does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 				status="FAILED"
 			fi
 		# No plasmid folder exists
 		else
 			printf "%-20s: %-8s : %s\\n" "plasmidFndr-plasFlow" "FAILED" "/plasmidFinder_on_plasFlow/ does not exist"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 			status="FAILED"
 		fi
 	fi
 else
 	printf "%-20s: %-8s : %s\\n" "plasFlow" "NA" "Assembly only isolate"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 fi

 if [[ -n "${QC_FAIL}" ]]; then
   QC_FAIL=${QC_FAIL%?}
   printf "%-20s: %-8s : %s\\n" "Auto Pass/FAIL" "FAIL" "$QC_FAIL"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
   status="FAILED"
 else
   printf "%-20s: %-8s : %s\\n" "Auto Pass/FAIL" "PASS" "Minimum Requirements met for coverage(30x)/ratio_stdev(<2.58)/min_length(>1000000) to pass auto QC filtering"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"
 fi


 echo "---------- ${sample_name} completed as ${status} ----------"  >> "${OUTDATADIR}/${sample_name}_pipeline_stats.txt"

 #Script exited gracefully (unless something else inside failed)
 exit 0
