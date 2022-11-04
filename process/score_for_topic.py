"""
Take main database (SQLite) file and JSON file of word probabilities.
Use the latter to compute average log-likelihoods of conjoined title/abstract, and write these 
back as score.
NEW 13/6/2022: looks for title/abstract translations to score instead in case language is not 'en'.

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.txt"

./process/score_for_topic.py $pgfile $blimodelfile


"""

import sys
import json 
import spacy
from spacy.matcher import Matcher                                                                                                                                                                                         
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, Integer, Float, MetaData
from math import log, isnan

# read command line
try:
	pgfile = sys.argv[1];			    del sys.argv[1]
	modelfile = sys.argv[1];			del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "pg_file model_file")
	sys.exit(1)

# read Postgres parameters
try:
	exec(open(pgfile).read())
except:
	print(f'Cannot open file {pgfile}')
	sys.exit(1)

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# create SQL table
metadata_obj = MetaData()
links = Table('links', metadata_obj,
              Column('link', String, primary_key=True),
              Column('title', String),
              Column('abstract', String),
              Column('title_translation', String),
              Column('abstract_translation', String),
              Column('score', Float),
              Column('BADLINK', Integer),
              Column('GOTTEXT', Integer),
              Column('GOTSCORE', Integer),
              Column('GOTTRANSLATION', Integer),
              Column('language', String)
             )

# read pre-computed BLI model
with open(modelfile, 'r') as jf:
    bli_loglik = json.load(jf)
jf.close()    

# load NLP pipeline
nlp = spacy.load('en_core_web_md') 

# global constants
LOGZERO = -20.0
MAXCALLS = 5000

##########################################################
# functions

def get_tokens(doc):
    """
    extract text tokens from doc
    """
    removal = ['ADV','PRON','CCONJ','PUNCT','PART','DET','ADP','SPACE', 'NUM', 'SYM']
    txt_words = [token.lemma_.lower() for token in doc
               if token.pos_ not in removal 
               and not token.is_stop 
               and token.is_alpha]
    return list(set(txt_words))

def bli_score(sentence):
    """
    compute score of a sentence
    """
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

##########################################################

def main():
    # initialise counters
    ncalls = 0
    ngood = 0

    # select database records
    selecter = select(links).\
        where(
            links.c.GOTTEXT == 1,
            links.c.GOTSCORE == 0,
            links.c.BADLINK == 0
            )
    # initialise update list for this domain
    update_list = []

    # connect to database
    with engine.connect() as conn:
        # loop over domains 
        records = conn.execute(selecter)
        for row in records:
            # stop if reached MAXCALLS
            if ncalls >= MAXCALLS:
                break
            # filter out bad records
            if row.title == "" or row.title == None or row.abstract == "" or row.abstract == None:
                update_list += [{
                            'linkvalue': row.link,
                            'scorevalue': LOGZERO, 
                            'badflagvalue': 1,
                            'scoreflagvalue' : 1
                            }]
                continue
            ncalls += 1
            # set text to score
            try:
                if row.language != 'en' and row.GOTTRANSLATION == 1:
                    doc = nlp( row.abstract_translation )
                    sents = clean_sentences(list(doc.sents)) + [row.title_translation]
                else:
                    doc = nlp( row.abstract )
                    sents = clean_sentences(list(doc.sents)) + [row.title]
                # ... and score
                score = sum( [bli_score(s) for s in sents] ) / len(sents)
                update_list += [{
                            'linkvalue': row.link,
                            'scorevalue': score, 
                            'badflagvalue': 0,
                            'scoreflagvalue' : 1
                            }]
                ngood += 1
                # verbose 
                print(f'{ncalls}: {row.title}')
            except:
                update_list += [{
                            'linkvalue': row.link,
                            'scorevalue': LOGZERO, 
                            'badflagvalue': 1,
                            'scoreflagvalue' : 0
                            }]
                continue
            # END OF __for row in records__
        # finish if no output
        if update_list == []:
            print(f'Read {ncalls} records, successfully scored {ngood}')
            return 0
        # ... otherwise make update instructions
        updater = links.update().\
                where(links.c.link == bindparam('linkvalue')).\
                values(
                    score = bindparam('scorevalue'),
                    BADLINK = bindparam('badflagvalue'),
                    GOTSCORE = bindparam('scoreflagvalue')
                    )
        # ... and commit to remote table
        conn.execute(updater, update_list)

        print(f'Read {ncalls} records, successfully scored {ngood}')
    return 0

##########################################################

if __name__ == '__main__':
    main()

# DONE