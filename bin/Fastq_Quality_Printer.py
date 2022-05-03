#!/usr/bin/env python3

#
# Description: Changes headers in SPAdes assembly fasta from contig# length=length# depth=depthx to Name_contig#_length_length#_depth_depthx
#
# Output location: standard out
#
# Usage: ./Fastq_Quality_Printer_3.py -1 path_to_R1 -2 path_to_R2 -u path_to_unpaired
#
# Modules required: None
#
# v1.1 (05/3/2022)
#
# Created by Rich Stanton (njr5@cdc.gov) & Nick Vlachos (nvx4@cdc.gov)
#

import sys
import argparse
from decimal import *
getcontext().prec = 4

def parseArgs(args=None):
	parser = argparse.ArgumentParser(description='Script to count quality metrics from paired fastq files')
	parser.add_argument('-1', '--r1', required=True, help='input R1 filename')
	parser.add_argument('-2', '--r2', required=True, help='input R2 filename')
	parser.add_argument('-u', '--unpaired', help='input unpaired filename')
	return parser.parse_args()

def Q20(input_string):
    Q20_Total = 0
    for letters in input_string:
        if (ord(letters) - 33) >=20:
            Q20_Total = Q20_Total + 1
    return Q20_Total

def Q30(input_string):
    Q30_Total = 0
    for letters in input_string:
        if (ord(letters) - 33) >=30:
            Q30_Total = Q30_Total + 1
    return Q30_Total

def Quality_Score_Lister(input_fastq):
    f= open(input_fastq, 'r')
    Q20_Total = 0
    Q30_Total = 0
    Total_Bases = 0
    Total_Reads = 0
    String1 = f.readline()
    while String1 != '':
        if String1 == '+\n':
            Total_Reads = Total_Reads + 1
            String1 = f.readline()
            Q20_Total = Q20_Total + Q20(String1[0:-1])
            Q30_Total = Q30_Total + Q30(String1[0:-1])
            Total_Bases = Total_Bases + len(String1[0:-1])
            String1 = f.readline()
        else:
            String1 = f.readline()
    f.close()
    Out = [Total_Reads, Total_Bases, Q20_Total, Q30_Total, Q20_Total / Total_Bases, Q30_Total / Total_Bases]
    return Out

def Quality_Score_Printer_3(fastq_R1, fastq_R2, fastq_unpaired):
    List1 = Quality_Score_Lister(fastq_R1)
    List2 = Quality_Score_Lister(fastq_R2)
    List3 = Quality_Score_Lister(fastq_unpaired)
    Total_Reads = str(List1[0] + List2[0] + List3[0])
    Total_Bases = str(List1[1] + List2[1] + List3[1])
    Q20_Total = str(List1[2] + List2[2] + List3[2])
    Q30_Total = str(List1[3] + List2[3] + List3[3])
    Q20_R1 = str(Decimal(List1[2]) / Decimal(List1[1]))
    Q20_R2 = str(Decimal(List2[2]) / Decimal(List2[1]))
    Q20_Unpaired = str(Decimal(List3[2]) / Decimal(List3[1]))
    Q30_R1 = str(Decimal(List1[3]) / Decimal(List1[1]))
    Q30_R2 = str(Decimal(List2[3]) / Decimal(List2[1]))
    Q30_Unpaired = str(Decimal(List3[3]) / Decimal(List3[1]))
    String1 = fastq_R1 + '\t' + Q20_Total + '\t' + Q30_Total + '\t' + str(List1[2]) + '\t' + str(List2[2]) + '\t' + str(List3[2]) + '\t' + Q20_R1 + '\t' + Q20_R2 + '\t' + Q20_Unpaired + '\t' + str(List1[3]) + '\t' + str(List2[3]) + '\t' + str(List2[3]) + '\t' + Q30_R1 + '\t' + Q30_R2+ '\t' + Q30_Unpaired + '\t' + Total_Bases + '\t' + Total_Reads
    print(String1)

def Quality_Score_Printer_2(fastq_R1, fastq_R2):
    List1 = Quality_Score_Lister(fastq_R1)
    List2 = Quality_Score_Lister(fastq_R2)
    Total_Reads = str(List1[0] + List2[0])
    Total_Bases = str(List1[1] + List2[1])
    Q20_Total = str(List1[2] + List2[2])
    Q30_Total = str(List1[3] + List2[3])
    Q20_R1 = str(Decimal(List1[2]) / Decimal(List1[1]))
    Q20_R2 = str(Decimal(List2[2]) / Decimal(List2[1]))
    #Q20_Unpaired = "N/A"
    Q30_R1 = str(Decimal(List1[3]) / Decimal(List1[1]))
    Q30_R2 = str(Decimal(List2[3]) / Decimal(List2[1]))
    #Q30_Unpaired = "N/A"
    String1 = fastq_R1 + '\t' + Q20_Total + '\t' + Q30_Total + '\t' + str(List1[2]) + '\t' + str(List2[2]) + '\t' +  Q20_R1 + '\t' + Q20_R2 + '\t' + str(List1[3]) + '\t' + str(List2[3]) + '\t' +  Q30_R1 + '\t' + Q30_R2+ '\t' + Total_Bases + '\t' + Total_Reads
    print(String1)

args = parseArgs()
if args.unpaired is not None:
	Quality_Score_Printer_3(args.r1, args.r2, args.unpaired)
else:
	Quality_Score_Printer_2(args.r1, args.r2)
