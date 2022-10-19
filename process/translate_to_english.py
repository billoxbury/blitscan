#!/usr/local/bin/python

"""
Take database records for which language field is not 'en' and GOTTRANSLATION is not yet set;
make Azure Translator query for fields 'title', 'abstract', 'pdftext'; and populate the 
translation fields 'title_translation', 'abstract_translation', 'pdftext_translation'.

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.txt"

./process/translate_to_english.py $pgfile

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
              Column('pdftext', String),
              Column('title_translation', String),
              Column('abstract_translation', String),
              Column('pdftext_translation', String),
              Column('GOTTEXT', Integer),
              Column('GOTTRANSLATION', Integer),
              Column('language', String)
             )

def main():
	# initialise counters
    ncalls = 0
    ngood = 0

    # select database records
    selecter = select(links).\
        where(
            links.c.GOTTEXT == 1,
            links.c.GOTTRANSLATION == 0,
            links.c.language != 'en'
            )
    # initialise update list for this domain
    update_list = []

    # connect to database
    with engine.connect() as conn:
        # loop over domains 
        records = conn.execute(selecter)
        for row in records:
            thislink = row.link
			# verbose
            print(thislink)
            ncalls += 1
            thislink = row.link
            # package text for translation
            body = [
                {'text': row.title},
                {'text': row.abstract},
                {'text': row.pdftext}]
            try:
                request = requests.post(constructed_url, params=params, headers=headers, json=body)
                response = request.json()
                title_translation = response[0]["translations"][0]["text"]
                abstract_translation = response[1]["translations"][0]["text"]
                pdftext_translation = response[2]["translations"][0]["text"]
                transflag = 1
                ngood += 1
                # verbose
                print(row.title)
                print(title_translation)
                print()
            except:
                title_translation = ""
                abstract_translation = ""
                pdftext_translation = ""
                transflag = 1
                continue
            # record updates
            update_list += [{
                            'linkvalue': row.link,
                            'ttransvalue': title_translation,
                            'atransvalue': abstract_translation, 
                            'ptransvalue': pdftext_translation,
                            'transflagvalue': transflag,
                            }]
            # END OF __for row in records__
        # finish if no output
        if update_list == []:
            print(f'Made total {ngood} translations out of {ncalls} calls')
            return 0
        # ... otherwise make update instructions
        updater = links.update().\
                where(links.c.link == bindparam('linkvalue')).\
                values(
                    title_translation = bindparam('ttransvalue'),
                    abstract_translation = bindparam('atransvalue'),
                    pdftext_translation = bindparam('ptransvalue'),
                    GOTTRANSLATION = bindparam('transflagvalue')
                    )
        # ... and commit to remote table
        conn.execute(updater, update_list)

    print(f'Made total {ngood} translations out of {ncalls} calls')
    return 0

##########################################################

if __name__ == '__main__':
	main()

# DONE