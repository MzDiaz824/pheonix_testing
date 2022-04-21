#!/bin/bash -l

#$ -o database_checker.out
#$ -e database_checker.err
#$ -N database_checker
#$ -cwd
#$ -q short.q

#
# Description: Script checks for file tag to see if database version is the same. If it is behind it will download the new set
#
# Usage ./database_checker.sh path_to_database_folder
#
# Modules required: None
#
# v1.0.0 (04/21/2022)
#
# Created by Nick Vlachos (nvx4@cdc.gov)
#

do_download="false"
# Checks for proper argumentation
if [[ $# -eq 0 ]]; then
	echo "No argument supplied to $0, exiting"
	exit 113
elif [[ "${1}" = "-h" ]]; then
	echo "Usage ./database_checker.sh path_to_config_file [-i]"
	echo "-i is too install databases, otherwise script just checks for existence"
	exit 0
elif [[ ! -d "${1}" ]]; then
	echo "No folder exists as ${1}...exiting"
	exit 113
else
	path_to_DBs="${1}"
fi

# Shows where databases should be (installed)
echo "${path_to_DBs}"

if [[ ! -f "${path_to_DBs}/DB_version.txt" ]]; then
	do_download="true"
else
	local_DB_version=$(tail -n1 "${path_to_DBs}/DB_version.txt" | cut -d'-' -f1)
	echo "Downloading latest database version file (wget ftp://ftp.cdc.gov/pub/QUAISAR-FTP/DB_version.txt)"
	wget -O "${path_to_DBs}/DB_version_remote.txt" "ftp://ftp.cdc.gov/pub/QUAISAR-FTP/DB_version.txt"
	remote_DB_version=$(tail -n1 "${path_to_DBs}/DB_version_remote.txt" | cut -d'-' -f1)
	if [[ "${local_DB_version}" = "${remote_DB_version}" ]]; then
		echo "Databases are up to date!"
	else
		echo "Databases need to be updated"
		do_update="true"
	fi
	rm "${path_to_DBs}/DB_version_remote.txt"
fi

if [[ "${do_download}" = "true" ]]; then
	echo "Downloading latest database version file (wget ftp://ftp.cdc.gov/pub/QUAISAR-FTP/DB_version.txt)"
	wget -O "${path_to_DBs}/DB_version.txt" "ftp://ftp.cdc.gov/pub/QUAISAR-FTP/DB_version.txt"
	do_update="true"
fi

if [[ "${do_update}" = "true" ]]; then
	DB_version=$(tail -n1 "${path_to_DBs}/DB_version.txt" | cut -d'-' -f1)
	echo "Downloading latest database tar file (wget ftp://ftp.cdc.gov/pub/QUAISAR-FTP/${DB_version}.tar.gz)"
	wget -O "${path_to_DBs}/DB_version_${DB_version}.tar.gz" "ftp://ftp.cdc.gov/pub/QUAISAR-FTP/${DB_version}.tar.gz"
	tar tzf "${path_to_DBs}/DB_version_${DB_version}.tar.gz" > "${path_to_DBs}/DB_version_${DB_version}_expanded.txt"
	tar -zvxf "${path_to_DBs}/DB_version_${DB_version}.tar.gz" -C "${path_to_DBs}"
fi
