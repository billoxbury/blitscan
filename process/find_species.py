"""
Read text columns 'title/abstract/pdftext' and update column 'species'.
'species' is a string formed by concatenating SISRecID's with | delimiter.
over the set of fields specified, using a taxonomy given as a command line argument.

E.g.

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.txt"
birdfile='/Volumes/blitshare/data/BirdLife_species_list_Jan_2022.xlsx'

./process/find_species.py $pgfile $birdfile

"""

import sys
import spacy
from spacy.matcher import PhraseMatcher
from spacy.tokens import Span
from spacy.lang.en import English
from spacy.pipeline import EntityRuler
import pandas as pd
import numpy as np
import re
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, Integer, Float, MetaData

# read command line
try:
	pgfile = sys.argv[1];			    del sys.argv[1]
	birdfile = sys.argv[1];				del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "pg_file species_file")
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
			  Column('pdftext', String),
			  Column('species', String),
              Column('BADLINK', Integer),
              Column('GOTTEXT', Integer),
              Column('GOTSPECIES', Integer)
             )

# global variable - id_dict will assign species id to commmon/scientific names
id_dict = dict()


##########################################################
# functions

def make_taxonomy_df():
    '''
    build species taxonomy
    '''
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

def make_tax_patterns(taxonomy_df):
    '''
    build taxonomy_patterns for NLP, and also construct id_dict 
    '''
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

def make_nlp_pipeline(taxonomy_patterns):
	'''
	build NLP pieline
	'''
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

##########################################################

def main():
    print("Reading taxonomy file")
    tax_df = make_taxonomy_df()
    
    print("Parsing taxonomy patterns")
    tax_patterns = make_tax_patterns(tax_df)
    
    print("Building NLP pipeline")
    nlp = make_nlp_pipeline(tax_patterns)
    
    print("Locating species mentions")
    # initialise counters
    ncalls = 0
    ngood = 0

    # select database records
    selecter = select(links).\
        where(
            links.c.GOTTEXT == 1,
            links.c.GOTSPECIES == 0,
            links.c.BADLINK == 0
            )
    # initialise update list for this domain
    update_list = []

    # connect to database
    with engine.connect() as conn:
        # loop over domains 
        records = conn.execute(selecter)
        for row in records:
            ncalls += 1
            # set text to search
            if row.title != None:
                txt = row.title
            else:
                txt = ''
            if row.abstract != None:
                txt = '\n'.join([txt, row.abstract])
            if row.pdftext != None:
                txt = '\n'.join([txt, row.pdftext])
            if txt == '':
                continue
            # otherwise proceed
            txt = clean_text(txt)
            doc = nlp(txt)
            ents = [ent.label_ for ent in doc.ents]
            if 'comName' in ents or 'sciName' in ents:
                sp_list = [ent.text.lower() for ent in doc.ents if ent.label_ in ['comName','sciName']]
                id_list = [id_dict[s] for s in sp_list]
                id_list = list(set(id_list))
                sp_list = list(set(sp_list)) # only used for verbose output
                id_string = '|'.join(id_list)
            else:
                sp_list = []
                id_string = ""
            update_list += [{
                            'linkvalue': row.link,
                            'speciesvalue': id_string, 
                            'speciesflagvalue': 1
                            }]
            if len(sp_list) > 0:
                ngood += 1
                print(f'{ncalls}: {id_string} {sp_list}')

            # END OF __for row in records__
        # finish if no output
        if update_list == []:
            print(f'Read {ncalls} records, found species in {ngood}')
            return 0
        # ... otherwise make update instructions
        updater = links.update().\
                    where(links.c.link == bindparam('linkvalue')).\
                    values(
                        species = bindparam('speciesvalue'),
                        GOTSPECIES = bindparam('speciesflagvalue')
                    )
        # ... and commit to remote table
        conn.execute(updater, update_list)

        print(f'Read {ncalls} records, found species in {ngood}')
    return 0

##########################################################

if __name__ == '__main__':
    main()

# DONE