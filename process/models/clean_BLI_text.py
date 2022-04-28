#!/usr/local/bin/python

"""
BLI text updates on species status are scraped by the R script 
'scrape/scrape_BLI_species.R' and text saved to 'data/BLI/master-BLI-yyyy-mm-dd.csv'.

This script reads that CSV, cleans the text and writes the result to a new column 'short_text'.

Run with
./process/clean_BLI_text.py infile outfile

E.g.
./process/models/clean_BLI_text.py ./data/master-BLI.csv ./data/master-BLI_OUT.csv
"""

import sys
import re
import pandas as pd

# read command line
try:
	infile = sys.argv[1]; del sys.argv[1]
	outfile = sys.argv[1]; del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "infile outfile")
	sys.exit(1)

# global variables
MIN_NR_WORDS = 4

# data structures
df = pd.read_csv(infile)
if not 'text_short' in df.columns:
	df['text_short'] = ["" for i in range(df.shape[0])]


# regex patterns
citation_patt = re.compile( r'\([A-Z|a-z][^)]+((19|20)\d{2}[a-z]?|in prep\.)[\]]?\)' )
justification_patt = re.compile( r'^(Justification of Red List Category|Population justification|Trend justification)[\n]?' )
conservation_patt = re.compile( r'^(Conservation Actions Underway|Conservation Actions Proposed)[\n]?' )
dlt = 'Text account compilers'


# custom text cleaner
def clean_text(text):
	out = text.strip()
	out = citation_patt.sub('', out)
	out = justification_patt.sub('', out)
	out = conservation_patt.sub('', out)
	dlt = 'Text account compilers'
	out = out.split(dlt)[0].strip()
	out =  re.sub('[\n|  ]+', ' ', out)
	out = re.sub(' \.', '.', out)
	return out.strip()

# main loop
def scan_table():
	global df 
	
	for i in range(df.shape[0]):
		# to process all, comment out the if:
		if df['text_short'][i] == "" or type( df['text_short'][i] ) != str:
			df.at[i, 'text_short'] = clean_text( df.iloc[i]['text_main'] )
	return(0)

def write_csv():
	df.to_csv(outfile, index = False)


##########################################################

def main():
	scan_table()
	write_csv()
	print("Output written to", outfile)

if __name__ == '__main__':
	main()
