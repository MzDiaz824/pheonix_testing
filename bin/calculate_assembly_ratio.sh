#!/bin/sh -l

#$ -o 	calc_rat.out
#$ -e 	calc_rat.err
#$ -N 	calc_rat
#$ -cwd
#$ -q short.q

#
# Description: script to Compare local assembly to the expected assembly size based upon an entrez lookup of best matching ani hit
#
# Usage: ./calculate_assembly_ratio.sh -n sample_name -p project [-c path_to_config_file] [-d path_to_database_file]  [-f 'genus species'] [-e explicit_path_to_isolate_folder]
#
# Output location: Varies on contents
#
# Modules required: Entrez
#
# v1.0.2 (08/18/2021)
#
# Created by Nick Vlachos (nvx4@cdc.gov)
#

#  Function to print out help blurb
show_help () {
	echo "Usage is ./calculate_assembly_ratio.sh -n sample_name -p project [-c path_to_config_file] [-d path_to_database_file] [-f \"genus species\"] [-e explicit_path_to_isolate_folder]"
}

# Parse command line options
options_found=0
while getopts ":h?n:p:c:d:f:e:" option; do
	options_found=$(( options_found + 1 ))
	case "${option}" in
		\?)
			echo "Invalid option found: ${OPTARG}"
      show_help
      exit 0
      ;;
		n)
			echo "Option -n triggered, argument = ${OPTARG}"
			sample_name=${OPTARG};;
		p)
			echo "Option -p triggered, argument = ${OPTARG}"
			project=${OPTARG};;
		c)
			echo "Option -c triggered, argument = ${OPTARG}"
			config=${OPTARG};;
		d)
			echo "Option -d triggered, argument = ${OPTARG}"
			db_path=${OPTARG};;
		e)
			echo "Option -e triggered, argument = ${OPTARG}"
			epath=${OPTARG};;
		f)
			echo "Option -f triggered, argument = ${OPTARG}"
			force="true"
			in_genus=$(echo "${OPTARG^}" | cut -d' ' -f1)
			in_species=$(echo "${OPTARG,,}" | cut -d' ' -f2);;
		:)
			echo "Option -${OPTARG} requires as argument";;
		h)
			show_help
			exit 0
			;;
	esac
done

# Show help info for when no options are given
if [[ "${options_found}" -eq 0 ]]; then
	echo "No options found"
	show_help
	exit
fi

if [[ -f "${config}" ]]; then
	echo "Loading special config file - ${config}"
	. "${config}"
else
	echo "Loading default config file"
	if [[ ! -f "./config.sh" ]]; then
		cp ./config_template.sh ./config.sh
	fi
	. ./config.sh
	cwd=$(pwd)
	config="${cwd}/config.sh"
fi

# Accounts for manual entry or passthrough situations
if [[ -f "${db_path}" ]]; then
	NCBI_ratio="${db_path}"
	NCBI_ratio_date=$(echo "${db_path}" | rev | cut -d'_' -f1 | cut -d'.' -f2 | rev)
fi

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

echo -e "Checking if directories exist:\nParent:${OUTDATADIR}\nANI:${OUTDATADIR}/ANI\nAssembly:${OUTDATADIR}/Assembly"
# Checks for proper argumentation
if [[ ! -d "${OUTDATADIR}" ]] || [[ ! -d "${OUTDATADIR}/ANI" ]] || [[ ! -d "${OUTDATADIR}/Assembly" ]]; then
	echo "No sample (or ANI or Assembly) folder exist, exiting"
	exit 1
fi

echo "Checking if Assembly_stats exists:${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv"
if [[ -f "${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv" ]]; then
	assembly_length=$(sed -n '16p' "${OUTDATADIR}/Assembly_Stats/${sample_name}_report.tsv" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3)
# Another method if we start seeing too many failures with main method
#elif
else
	echo "No Assembly_Stats exists, have not added second method, so cannot continue"
	exit
fi
counter=0

if [[ ! "${force}" ]]; then
	echo "Checking if Tax summary exists:${OUTDATADIR}/${sample_name}.tax"
	if  [[ -f "${OUTDATADIR}/${sample_name}.tax" ]]; then
		# All tax files seem to have an extra empty line. To avoid messing anything else up, we'll deal with it as is
		genus=$(head -n7 "${OUTDATADIR}/${sample_name}.tax" | tail -n1 | cut -d'	' -f2)
		species=$(head -n8 "${OUTDATADIR}/${sample_name}.tax" | tail -n1 | cut -d'	' -f2)
		total_tax="${genus} ${species}"
		#echo "${genus} ${species}"
	else
		echo "No Tax file to find accession for lookup, exiting"
		exit
	fi
else
	genus="${in_genus}"
	species="${in_species}"
	total_tax="${genus} ${species}	(selected manually)"
fi

while IFS='' read -r line; do
	IFS=$'\t' read -a arr_line <<< "$line"
	#echo "${arr_line[0]}"
	#echo  "${genus} ${species} vs ${arr_line[0]}"
	if [[ "${genus} ${species}" = "${arr_line[0]}" ]]; then
		taxid="${arr_line[19]}"
		if [ "${taxid}" = -2 ]; then
			taxid="No mode available when determining tax id"
		elif [ "${taxid}" = -1 ]; then
			taxid="No tax id given or empty when making lookup"
		fi
		expected_length=$(echo "scale=0; 1000000 * ${arr_line[4]} / 1 " | bc | cut -d'.' -f1)
		echo "${arr_line[5]}"
		stdev=$(echo "scale=4; 1000000 * ${arr_line[5]} /1 " | bc | cut -d"." -f1)
		if [[ "${stdev}" = "0" ]]; then
			stdev="Single_Reference"
			stdevs=0
		else
			if [[ "${assembly_length}" -gt "${expected_length}" ]]; then
				bigger="${assembly_length}"
				smaller="${expected_length}"
			else
				smaller="${assembly_length}"
				bigger="${expected_length}"
			fi
			stdevs=$(echo "scale=4 ; ( ${bigger} - ${smaller} ) / ${stdev}" | bc)
		fi


		break
	#elif [[ "${genus} ${species}" < "${arr_line[0]}" ]]; then
	elif [[ "${genus:0:1}" < "${arr_line[0]:0:1}" ]]; then
		break
	fi
done < "${NCBI_ratio}"
#echo "looked in ${NCBI_ratio}"


if [[ ! ${expected_length} ]]; then
	echo "No expected length was found to compare to"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_StDev: ${stdev}\nIsolate_St.Devs: ${stdevs}\nActual_length: ${assembly_length}\nExpected_length: ${expected_length}\nRatio: -1" >  "${OUTDATADIR}/${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
	exit
elif [[ ! ${assembly_length} ]]; then
	echo "No assembly length was found to compare with"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_StDev: ${stdev}\nIsolate_St.Devs: ${stdevs}\nActual_length: ${assembly_length}\nExpected_length: ${expected_length}\nRatio: -2" >  "${OUTDATADIR}/${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
	exit
fi

ratio=$(echo "scale=6; ${assembly_length} / ${expected_length}" | bc | awk '{printf "%.4f", $0}')

echo -e "Actual - ${assembly_length}\nExpected - ${expected_length}\nRatio - ${ratio}\nSpecies_St.Devs - ${stdev}\nIsolate_St.Dev:${stdevs}"


echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_St.Dev: ${stdev}\nIsolate_St.Devs: ${stdevs}\nActual_length: ${assembly_length}\nExpected_length: ${expected_length}\nRatio: ${ratio}" >  "${OUTDATADIR}/${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
