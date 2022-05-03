#!/usr/bin/env python3

#
# Description: Parses the .json output file from Busco to generate a tab-delimited summary file with the % Busco matches, total busco matches, DB length, and DB name
#
# Output location: standard out
#
# Usage: ./Busco_Data_Writer.py -i busco_short_summary_json -o output_file [-n]
#
# Modules required: None
#
# v1.0 (05/03/2022)
#
# Created by Rich Stanton (njr5@cdc.gov)
#

import sys
import json
import argparse
from decimal import *
getcontext().prec = 4

def BUSCO_Data(input_json):
    f = open(input_json)
    data = json.load(f)
    Fraction = str(Decimal(data['C']) / Decimal(data['dataset_total_buscos']))
    DB = data['dataset'].split('/')[-1]
    Out = [Fraction, str(data['C']), data['dataset_total_buscos'], DB]
    return Out

def Busco_Data_Writer(input_json, output_file):
    Info = BUSCO_Data(input_json)
    Out = open(output_file, 'w')
    Out.write('Fraction\tBusco_Complete\tDB_Length\tDB_Name\n')
    Line = '\t'.join(Info)
    Out.write(Line)
    Out.close()

def Busco_Data_Writer_NoHead(input_json, output_file):
    Info = BUSCO_Data(input_json)
    Out = open(output_file, 'w')
    Line = '\t'.join(Info)
    Out.write(Line)
    Out.close()
    

def parseArgs(args=None):
	parser = argparse.ArgumentParser(description='Script to output info from BUSCO json into a tab delimited file')
	parser.add_argument('-i', '--input', required=True, help='input json file')
	parser.add_argument('-o', '--output', required=True, help='output file name')
	parser.add_argument('-n', '--nohead', help='input unpaired filename', action='store_true')
	return parser.parse_args()

args=parseArgs()

if args.nohead:
    Busco_Data_Writer_NoHead(args.input, args.output)
else:
    Busco_Data_Writer(args.input, args.output)
    
    
