"""
Reviews all database records where language is not present and uses spaCy language detector to determine language.

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.txt"

python3 ./process/detect_language.py $pgfile


"""

import sys
import spacy
from spacy.language import Language

from spacy_language_detection import LanguageDetector
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, Integer, Float, MetaData

# read command line
try:
	pgfile = sys.argv[1];			    del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "pg_file")
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
              Column('gottext', Integer),
              Column('language', String)
             )

def get_lang_detector(nlp, name):
    return LanguageDetector(seed=42)  # We use the seed 42

# load NLP pipeline
nlp = spacy.load('en_core_web_md') 
Language.factory("language_detector", func=get_lang_detector)
nlp.add_pipe('language_detector', last=True)

# global constants
MAXCALLS = 5000

##########################################################

def main():
    # initialise counters
    ncalls = 0
    ngood = 0

    # select database records
    selecter = select(links).\
        where(
            links.c.gottext == 1,
            links.c.language == ''
            )
    # initialise update list for this domain
    update_list = []

    # connect to database
    with engine.connect() as conn:
        records = conn.execute(selecter)
    # MAIN LOOP
    for row in records:
        thislink = row.link
        # stop if reached MAXCALLS
        if ncalls >= MAXCALLS:
            break
        # skip bad records
        if row.title == "" or row.title == None or row.abstract == "" or row.abstract == None:
            continue
        ncalls += 1
        # set text to score
        try:
            text = '\n'.join([row.title, row.abstract])
            doc = nlp(text)
            language = doc._.language['language']
            update_list += [{
                    'linkvalue': thislink,
                    'langvalue': language
                }]
            ngood += 1
            if language != 'en':
                print(f'{ncalls}: {language}')
                print(f'{row.title}')
        except:
            continue
    # END OF MAIN LOOP

    # finish if no output
    if update_list == []:
        print(f'No language updates to make - read {ncalls} records')
        return 0
    # ... otherwise make update instructions
    updater = links.update().\
            where(links.c.link == bindparam('linkvalue')).\
            values(
                language = bindparam('langvalue')
                )
    # ... and commit to remote table
    with engine.connect() as conn:
        conn.execute(updater, update_list)
        conn.commit()
    
    print(f'Read {ncalls} records, successful language-id {ngood}')
    return 0

##########################################################

if __name__ == '__main__':
    main()

# DONE