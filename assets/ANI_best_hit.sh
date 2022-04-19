#!/bin/sh -l

#$ -o run_ANI_sketch.out
#$ -e run_ANI_sketch.err
#$ -N run_ANI_sketch
#$ -pe smp 1
#$ -cwd
#$ -q short.q

#
# Description: Script to sort and highlight best ANI hit sample from identity and coverage matrix files
#
# Usage: ./run_ANI_REFSEQ.sh -i input_folder (with identity and coverage files) -o output_file (full path)
#
# Output location: default_config.sh_output_location/run_ID/sample_name/ANI/
#
# V1.0 (04/19/2022)
#
# Created by Nick Vlachos (nvx4@cdc.gov)
#


#  Function to print out help blurb
show_help () {
	echo "./ANI_best_hit.sh -i input_sample_folder (with identity and coverage files)"
}

# Parse command line options
options_found=0
while getopts ":h?i:O:" option; do
	options_found=$(( options_found + 1 ))
	case "${option}" in
		\?)
			echo "Invalid option found: ${OPTARG}"
      show_help
      exit 0
      ;;
		i)
			echo "Option -i triggered, argument = ${OPTARG}"
			input_folder=${OPTARG};;
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
	exit 1
fi

if [[ ! -d "${input_folder}" ]]; then
	echo "Sample folder does not exist"
	exit 21
fi

if [[ -d "${input_folder}/ANI" ]]; then
	if [[ ! -f "${input_folder}/ANI/ANIm_REFSEQ/ANIm_percentage_identity.tab" ]] || [[ ! -f "${input_folder}/ANI/ANIm_REFSEQ/ANIm_alignment_coverage.tab" ]]; then
		echo "Necessary calc file missing in ${input_folder}/ANI/ANIm_REFSEQ, either ANIm_alignment_coverage.tab or ANIm_percentage_identity.tab, exiting"
		exit 22
	fi
else
	echo "Sample ANI folder does not exist"
	exit 23
fi

sample_name=$(echo "${input_folder}" | rev | cut -d '/' -f1)


#Extracts the query sample info line for percentage identity from the percent identity file
while IFS='' read -r line || [ -n "$line" ]; do
#	echo "!-${line}"
	if [[ ${line:0:6} = "sample" ]]; then
		sample_identity_line=${line}
#		echo "found it-"$sample_identity_line
		break
	fi
done < "${input_folder}/ANI/ANIm_REFSEQ/ANIm_percentage_identity.tab"

#Extracts the query sample info line for percentage identity from the percent identity file
while IFS='' read -r line || [ -n "$line" ]; do
#	echo "!-${line}"
	if [[ ${line:0:6} = "sample" ]]; then
		sample_coverage_line=${line}
#		echo "found it-"$sample_identity_line
		break
	fi
done < "${input_folder}/ANI/ANIm_REFSEQ/ANIm_alignment_coverage.tab"

header_line=$(head -n 1 "${input_folder}/ANI/ANIm_REFSEQ/ANIm_percentage_identity.tab")

#Arrays to read sample names and the %ids for the query sample against those other samples
IFS="	" read -r -a samples <<< "${header_line}"
IFS="	" read -r -a percents <<< "${sample_identity_line}"
IFS="	" read -r -a coverages <<< "${sample_coverage_line}"

#How many samples were compared
n=${#samples[@]}

owd=$(pwd)
cd "${input_folder}/ANI"
fasta_ref_folder=$(find . -maxdepth 1 -name "localANIDB_REFSEQ*" -type d | sort -nr -t'_' -k3,3 | head -n1 | cut -d'/' -f2)
cd "${owd}"
ref_date=$(echo "${fasta_ref_folder}" | cut -d'_' -f3)

#Extracts all %id against the query sample (excluding itself) and writes them to file
for (( i=0; i<n; i++ ));
do
#	echo ${i}-${samples[i]}
	if [[ ${samples[i]:0:6} = "sample" ]];
	then
#		echo "Skipping ${i}"
		continue
	fi
	definition=$(head -1 "${input_folder}/ANI/${fasta_ref_folder}/${samples[i]}.fasta")
	# Prints all matching samples to file (Except the self comparison) by line as percent_match  sample_name  fasta_header
	echo "${percents[i+1]}	${coverages[i+1]}	${samples[i]}	${definition}" >> "${input_folder}/ANI/best_hits.txt"
done

#Sorts the list in the file based on %id (best to worst)
sort -nr -t' ' -k1 -o "${input_folder}/ANI/best_hits_ordered.txt" "${input_folder}/ANI/best_hits.txt"
#Extracts the first line of the file (best hit)
best=$(head -n 1 "${input_folder}/ANI/best_hits_ordered.txt")
#Creates an array from the best hit
IFS='	' read -r -a def_array <<< "${best}"
#echo -${def_array[@]}+
#Captures the assembly file name that the best hit came from
best_file=${def_array[2]}
best_file=$(echo "${best_file}" | rev | cut -d'_' -f2- | rev)
#Formats the %id to standard percentage (xx.xx%)
best_percent=$(awk -v per="${def_array[0]}" 'BEGIN{printf "%.2f", per * 100}')
best_coverage=$(awk -v per="${def_array[1]}" 'BEGIN{printf "%.2f", per * 100}')
#echo "${best_file}"
# Pulling taxonomy from filename which was looked up. Can possibly be out of date. REFSEQ file will ALWAYS be current though
best_genus=$(echo "${best_file}" | cut -d'_' -f1)
best_species=$(echo "${best_file}" | cut -d'_' -f2)
best_organism_guess="${best_genus} ${best_species}"

# Uncomment this if you want to restrict ID to only genus species, without more resolute definition
#best_organism_guess_arr=($best_organism_guess})
#best_organism_guess="${best_organism_guess_arr[@]:0:2}"

#Creates a line at the top of the file to show the best match in an easily readable format that matches the style on the MMB_Seq log
echo -e "${best_percent}%ID-${best_coverage}%COV-${best_organism_guess}(${best_file}.fna)\\n$(cat "${input_folder}/ANI/best_hits_ordered.txt")" > "${input_folder}/ANI/${sample_name}_vs_REFSEQ_${ref_date}_best_ANI.txt"

# Removes the transient hit files
if [ -s "${input_folder}/ANI/best_hits.txt" ]; then
	rm "${input_folder}/ANI/best_hits.txt"
#	echo "1"
fi
if [ -s "${input_folder}/ANI/best_hits_ordered.txt" ]; then
	rm "${input_folder}/ANI/best_hits_ordered.txt"
#	echo "2"
fi
