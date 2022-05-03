#!/usr/local/bin/python

"""
Take a CSV file with fields 'title', 'abstract', 'score'; and JSON file of word probabilities.
Use the latter to compute average log-likelihoods of conjoined title/abstract, and wrote these 
back as score.

"""

import sys
import json 
import spacy
from spacy.matcher import Matcher                                                                                                                                                                                         
import pandas as pd  
from math import log, isnan
from datetime import datetime, timedelta

# global constants
LOGZERO = -20.0

# read command line
try:
	datafile = sys.argv[1];			 	del sys.argv[1]
	modelfile = sys.argv[1];			del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "csvfile modelfile")
	sys.exit(1)

# read data frame with text fields
df = pd.read_csv(datafile)

# read pre-computed BLI model
with open(modelfile, 'r') as jf:
    bli_loglik = json.load(jf)
jf.close()    

# load NLP pipeline
nlp = spacy.load('en_core_web_md') 

# function to extract text tokens from doc
def get_tokens(doc):
    removal = ['ADV','PRON','CCONJ','PUNCT','PART','DET','ADP','SPACE', 'NUM', 'SYM']
    txt_words = [token.lemma_.lower() for token in doc
               if token.pos_ not in removal 
               and not token.is_stop 
               and token.is_alpha]
    return list(set(txt_words))

def bli_score(sentence):
    if isinstance(sentence, str):
        doc = nlp(sentence)
    else:
        doc = sentence
    tokens = get_tokens(doc)
    ct = 0
    for tok in tokens:
        if tok in bli_loglik.keys():
            ct += bli_loglik[tok]
        else:
            ct += LOGZERO
    return ct / len(tokens)

"""
# date routine
def is_recent(s, nr_days = 7):
    #s is a string of the for "yyyy-mm-dd"
    date = datetime.strptime(s, "%Y-%m-%d")
    if date > datetime.now() - timedelta(days = nr_days):
        return True
    else:
        return False
"""

def verbs(sent):
    pattern=[
        {'POS': 'VERB', 'OP': '?'},
        {'POS': 'ADV', 'OP': '*'},
        {'POS': 'VERB', 'OP': '+'}
    ]
    # instantiate a Matcher instance
    matcher = Matcher(nlp.vocab) 
    # add pattern to matcher
    matcher.add('verb-phrases', [pattern])
    d = nlp(sent.text)
    # call the matcher to find matches 
    matches = matcher(d)
    spans = [d[start:end] for _, start, end in matches] 
    return spans

def clean_sentences(sents):
    sentences = [s for s in sents if len(verbs(s)) > 0 and
                    len(s) > 3]
    return sentences

def main():
	global df
	# apply topic scoring to title/abstract
	print("Computing item scores")
	for i in range(df.shape[0]): 
		if (df.at[i, 'GOTSCORE'] == 1 or df.at[i, 'BADLINK'] == 1): continue
		if not (isinstance(df.at[i, 'title'], str) and \
				isinstance(df.at[i, 'abstract'], str)):
			df.at[i, 'score'] = LOGZERO
			continue
		try:
			doc = nlp( df.at[i, 'abstract'] )
			sents = clean_sentences(list(doc.sents)) + [df.at[i, 'title']]
			df.at[i, 'score'] = sum( [bli_score(s) for s in sents] ) / len(sents)
			df.at[i, 'GOTSCORE'] = 1
		except:
			continue

	bad_rows = [i for i in range(df.shape[0]) if df.at[i,'score'] == LOGZERO]
	df.at[bad_rows, 'BADLINK'] = 1
	df = df.sort_values(by = ['score'], ascending = False )
	df.to_csv(datafile, index = False)
	print(f"Done and written to {datafile}")        

##########################################################

if __name__ == '__main__':
	main()
