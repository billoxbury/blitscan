"""
Take database records for which language field is not 'en' and GOTTRANSLATION is not yet set;
make Azure Translator query for fields 'title', 'abstract'; and populate the 
translation fields 'title_translation', 'abstract_translation'.

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.txt"

python3 ./process/translate_to_english.py $pgfile

"""

import os, sys
import requests, uuid
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, Integer, MetaData

# read command line
try:
	pgfile = sys.argv[1];			        del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "pg_file")
	sys.exit(1)

# read Postgres parameters
try:
	exec(open(pgfile).read())
except:
	print(f'Cannot open file {pgfile}')
	sys.exit(1)

# global constants
MAXCALLS = 1000

# Subscription key endpoint, parameters etc
subscription_key = os.environ['AZURE_TRANSLATION_SUBSCRIPTION_KEY']
endpoint = os.environ['AZURE_TRANSLATION_ENDPOINT']
location = os.environ['AZURE_TRANSLATION_LOCATION']
constructed_url = endpoint + '/translate'
params = {
    'api-version': '3.0',
    'to': 'en'
}
headers = {
    'Ocp-Apim-Subscription-Key': subscription_key,
    'Ocp-Apim-Subscription-Region': location,
    'Content-type': 'application/json',
    'X-ClientTraceId': str(uuid.uuid4())
}

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
              Column('gottext', Integer),
              Column('gottranslation', Integer),
              Column('gotspecies', Integer),
              Column('species', String),
              Column('language', String)
             )

def main():
	# initialise counters
    ncalls = 0
    ngood = 0

    # select database records - restrict to those known to be non-English and to contain species mentions
    selecter = select(links).\
        where(
            links.c.gottext == 1,
            links.c.gotspecies == 1,
            links.c.gottranslation == 0,
            links.c.language != 'en',
            links.c.species != '',
            links.c.species != None
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
        # package text for translation
        body = [
            {'text': row.title},
            {'text': row.abstract},
            ]
        try:
            request = requests.post(constructed_url, params=params, headers=headers, json=body)
            response = request.json()
            langs = [r['detectedLanguage']['language'] for r in response]
            language = '|'.join(list(set(langs)))
            # skip next bit if language is all English
            if language == 'en':
                update_list += [{
                        'linkvalue': thislink,
                        'ttransvalue': '',
                        'atransvalue': '', 
                        'langvalue': 'en',
                        'transflagvalue': 1
                        }]
                continue
            # otherwise proceed
            title_translation = response[0]["translations"][0]["text"]
            abstract_translation = response[1]["translations"][0]["text"]
            transflag = 1
            ngood += 1
            # verbose
            print(f'{ncalls}: {row.title}')
            print(f'{language} --> {title_translation}')
        except Exception as ex:
            print(response['error']['message'])
            title_translation = ""
            abstract_translation = ""
            language = row.language
            transflag = 0
            continue
        # record updates
        update_list += [{
                        'linkvalue': row.link,
                        'ttransvalue': title_translation,
                        'atransvalue': abstract_translation, 
                        'langvalue': language,
                        'transflagvalue': transflag
                        }]
    # END OF MAIN LOOP
    # finish if no output
    if update_list == []:
        print(f'Made total {ngood} translations out of {ncalls} calls')
        return 0

    # ... otherwise make update instructions
    updater = links.update().\
            where(links.c.link == bindparam('linkvalue')).\
            values(
                language = bindparam('langvalue'),
                title_translation = bindparam('ttransvalue'),
                abstract_translation = bindparam('atransvalue'),
                gottranslation = bindparam('transflagvalue')
                )
    # ... and commit to remote table
    with engine.connect() as conn:
        conn.execute(updater, update_list)
        conn.commit()

    print(f'Made total {ngood} translations out of {ncalls} calls')
    return 0

##########################################################

if __name__ == '__main__':
	main()

# DONE