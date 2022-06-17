#!/usr/local/bin/python

"""
Filters master data frame down to presentation (TX) dataframe based on score quantile threshold.

E.g.
./process/make_tx_dataframe.py $infile $outfile

"""

import sys
from datetime import datetime
from pathlib import Path
import pandas as pd
import numpy as np
import re

# global constants
LOGZERO = -20.0
TX_THRESHOLD = 0.1 # score quantile below which items are discarded for TX

# read command line
try:
	infilename = sys.argv[1];			del sys.argv[1]
	outfilename = sys.argv[1];			del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "infile outfile")
	sys.exit(1)

# paths
infile = Path(infilename)
outfile = Path(outfilename)

# read data frame
df = pd.read_csv(infile, header=0).fillna('')

# make slimmed-down data frame for Text Explorer
def make_tx_data_frame(df):
	"""
	restrict to rows with BADLINK false, GOTSCORE true and score not 'log zero';
	then restrict to scores in the upper 60% or with >0 number of species mentions
	or explicitly referring to 'bird' or 'avian'... 
	"""
	avian = re.compile(r'bird|avian')

	mask1 = (df['BADLINK'] == 0)
	mask2 = (df['GOTSCORE'] == 1)
	mask = [(a and b) for a,b in zip(mask1, mask2)]

	df_tx = df.loc[mask]
	df_tx = df_tx.loc[df_tx['score'] > LOGZERO]
	
	scores = list(df_tx['score'])
	threshold_score = np.quantile(scores, TX_THRESHOLD)

	mask1 = (df_tx['score'] > threshold_score)
	mask2 = [len(s) > 2 for s in df_tx['species']]
	mask3 = [bool(avian.search(a)) for a in df_tx['abstract']]
	mask = [(a or b or c) for a,b,c in zip(mask1, mask2, mask3)]
	df_tx = df_tx.loc[mask]

	return df_tx

###########################################################

def main():
	
	df_tx = make_tx_data_frame(df)
	df_tx.to_csv(outfile, index = False)
	print(f'{df_tx.shape[0]} records written to {outfilename}')
	return 0

##########################################################

if __name__ == '__main__':
	main()
