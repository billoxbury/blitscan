#!/usr/local/bin/python

"""
Take a CSV file with one or more text columns and add new columns 'species' and 'avian'.
'species' is a list (written as a string '[*,*,*]') of common and scientific names found
over the set of fields specified, using a taxonomy given as a commend line argument.
'avian' is a boolean variable which marks either that the species list is nonempty, or that one or more of the specified field matches a simple regex (e.g. r'(bird|avian)')

E.g. 

infile="data/PLOS/master-2022-02-07.csv"
outfile="data/PLOS/master-2022-02-08.csv"
birdfile="data/taxonomy/BirdLife_species_list_Jan_2022.xlsx"

infile="data/google/master_text.csv"
outfile="data/google/master_text.csv"
birdfile="data/taxonomy/BirdLife_species_list_Jan_2022.xlsx"

./process/find_species.py $infile $outfile $birdfile title,abstract

"""

from multiprocessing.context import _default_context
import sys
from pathlib import Path
from datetime import datetime

import spacy
from spacy.matcher import PhraseMatcher
from spacy.tokens import Span
from spacy.lang.en import English
from spacy.pipeline import EntityRuler

import pandas as pd
import numpy as np
import re

# global constants
LOGZERO = -20.0
TX_THRESHOLD = 0.0 # score quantile below which items are discarded for TX

# read command line
try:
	infilename = sys.argv[1];			del sys.argv[1]
	outfilename = sys.argv[1];			del sys.argv[1]	
	birdfilename = sys.argv[1];			del sys.argv[1]	
	fields = sys.argv[1].split(',');	del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "infile outfile birdfile text_fields")
	sys.exit(1)

# paths
infile = Path(infilename)
outfile = Path(outfilename)
birdfile = Path(birdfilename)

# global variables
id_dict = dict()

# check the text field are in the input file
def make_input_df():
	global fields
	df = pd.read_csv(infile, header=0).fillna('')
	df_names = df.columns.to_list()
	for f in fields:
		if f not in df_names:
			fields.remove(f)
	if len(fields) == 0:
		print(sys.argv[0],': invalid text fields', fields)
		sys.exit(1)
	else:
		print("Found %d valid text fields in data" % len(fields)) 
		return df

# build bird taxonomy
def make_taxonomy_df():
    taxonomy_df = pd.read_excel(birdfile, header=0, dtype=str).fillna('')
    new_tax_columns = {
    'Common name': 'comName',
    'Scientific name': 'sciName',
    'Synonyms': 'syn',
    'Alternative common names' : 'alt',
    'SISRecID' : 'id'
    }
    taxonomy_df.rename(columns=new_tax_columns, inplace=True)
    return taxonomy_df.iloc[:,0:5]

# build taxonomy_patterns
def make_tax_patterns(taxonomy_df):

    # Row-wise operations (index i):
    def com_name(i):
        global id_dict
        # outputs a list of names, each one a list of lower-case words
        main = taxonomy_df.iloc[i,:]['comName'].lower()
        id_dict[main] = taxonomy_df.at[i,'id']
        out = [main.split()]
        if len(taxonomy_df.at[i,'alt']) > 0:
            alt_names = [x.strip() for x in taxonomy_df.at[i,'alt'].split(',')]
            alt_names = [x.lower() for x in alt_names]
            for x in alt_names:
                id_dict[x] = taxonomy_df.at[i,'id']
                out += [x.split()]
        return out

    def sci_name(i):
        global id_dict
        # outputs a list of names, each one a list of lower-case words
        main = taxonomy_df.iloc[i,:]['sciName'].lower()
        id_dict[main] = taxonomy_df.at[i,'id']
        out = [main.split()]
        if len(taxonomy_df.at[i,'syn']) > 0:
            syn_names = [x.strip() for x in taxonomy_df.at[i,'syn'].split(',')]
            syn_names = [x.lower() for x in syn_names]
            for x in syn_names:
                id_dict[x] = taxonomy_df.at[i,'id']
                out += [x.split()]
        return out

    # build pattern list
    n_species = taxonomy_df.shape[0]
    tp = [ 
    [{'label' : 'comName', 'pattern': [{'LOWER': x} for x in y]}
    for y in com_name(i)]
    for i in range(n_species) if len(com_name(i)) > 0] + \
    [
    [{'label' : 'sciName', 'pattern': [{'LOWER': x} for x in y]}
    for y in sci_name(i)]
    for i in range(n_species) if len(sci_name(i)) > 0]
    # tidy up
    tp = sum(tp, [])
    tp = [x for x in tp if len(x['pattern']) > 0]
    return tp

# build NLP pieline
def make_nlp_pipeline(taxonomy_patterns):
	nlp = spacy.load('en_core_web_md')
	nlp.add_pipe('sentencizer')
	config = {
	"phrase_matcher_attr": None,
	"validate": True,
	"overwrite_ents": True,
	"ent_id_sep": "||",
	}
	tax_ruler = nlp.add_pipe('entity_ruler', config = config)
	tax_ruler.add_patterns(taxonomy_patterns)
	return nlp

# function to strip off any HTML formatting
def clean_text(txt):
	return re.sub('<b>|</b>|<i>|</i>|\\(|\\)', " ", txt)

# locate records with species mentions
def find_species_records(df, nlp):
	global fields
	# loop over the data frame
	count = 0
	for i in range(df.shape[0]):
		# skip if bad link or already done
		if df.at[i, 'GOTSPECIES'] == 1 or df.at[i, 'BADLINK'] == 1:
			continue
		# otherwise proceed
		id_list = []
		sp_list = []
		# check if need to use English translations
		if df.at[i, 'language'] != 'en' and df.at[i, 'GOTTRANSLATION'] == 1:
			fields = [f + '_translation' for f in fields]
		# then proceed
		for f in fields:
			txt = clean_text(df[f][i])
			doc = nlp(txt)
			ents = [ent.label_ for ent in doc.ents]
			if 'comName' in ents or 'sciName' in ents:
				sp_list += [ent.text.lower() for ent in doc.ents if ent.label_ in ['comName','sciName']]
				id_list += [id_dict[ent.text.lower()] for ent in doc.ents if ent.label_ in ['comName','sciName']]
		id_list = list(set(id_list))
		sp_list = list(set(sp_list))
		id_string = '|'.join(id_list)
		df.at[i,'species'] = id_string
		if len(id_list) > 0:
			count += 1
			print(f'{i}: {id_string} {sp_list}')
		# and set flag
		df.at[i, 'GOTSPECIES'] = 1
	return df

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
	
	master_df = make_input_df()
	
	print("Reading taxonomy file"); sys.stdout.flush()
	tax_df = make_taxonomy_df()
	
	print("Parsing taxonomy patterns"); sys.stdout.flush()
	tax_patterns = make_tax_patterns(tax_df)
	
	print("Building NLP pipeline"); sys.stdout.flush()
	nlp = make_nlp_pipeline(tax_patterns)
	
	print("Locating species mentions")
	master_df = find_species_records(master_df, nlp)
	
	print(f"{master_df.shape[0]} records written to {infilename}")
	master_df.to_csv(infile, index = False)

	df_tx = make_tx_data_frame(master_df)
	df_tx.to_csv(outfile, index = False)
	print(f'{df_tx.shape[0]} records written to {outfilename}')
	print(f"TX version written to {outfilename}")
	
	print("Done")

##########################################################
#import cProfile, pstats

if __name__ == '__main__':

	#profiler = cProfile.Profile()
	#profiler.enable()
	main()
	#profiler.disable()
	#stats = pstats.Stats(profiler).sort_stats('tottime')
	#stats.print_stats()   
	#stats.dump_stats(outpath / "python.log")
