#!/usr/local/bin/python

"""
Downloads PDF files for Wiley SCB articles

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.R"
pdfpath="/Volumes/blitshare/data/wiley/pdf"

./scrape/get_wiley_pdf.py $pgfile $pdfpath

"""

import os, sys 
import re
from sqlalchemy import create_engine, text
import pandas as pd
from dateutil.parser import parse
from datetime import datetime
import time

# read command line
try:
	pgfile = sys.argv[1];			        del sys.argv[1]
	pdfpath = sys.argv[1];			        del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "pg_file pdf_path")
	sys.exit(1)

# read Postgres parameters
try:
	exec(open(pgfile).read())
except:
	print(f'Cannot open file {pgfile}')
	sys.exit(1)

# normalise path
pdfpath = re.sub('/$','', pdfpath)

# Wiley TDM account 
wileyToken = os.environ['WILEY_TDM_TOKEN']
api_prefix = 'https://api.wiley.com/onlinelibrary/tdm/v1/articles/'
WAITTIME = 0.5

# date variables
MAXAGE = 2200
today = datetime.now().date()

# local database query to get DOIs
scb_query = '\
        SELECT doi,created,"container.title" FROM dois \
        WHERE publisher LIKE \'%Wiley%\' \
        AND "container.title" like \'Conservation%\' \
        '

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# ... and get DOIs
with engine.connect() as conn:
    result = conn.execute(text(scb_query))
    dois = result.all()

# build main data frame
df = pd.DataFrame(list(set(dois)))

# delete DOIs older than MAXAGE days
too_old = []
for i in range(df.shape[0]):
    date = parse(df.at[i,'created'], fuzzy=True).date()
    age = (today - date).days
    if age > MAXAGE:
        too_old += [i]
if len(too_old) > 0:
    df = df.drop(too_old)
print(f'Read {df.shape[0]} DOIs not older than {MAXAGE} days')

# path and URL encodings
def doi_download_url(doi):
    return api_prefix + re.sub('/', '%2F', doi)
def doi_pdfname(doi):
    return re.sub('/','_', doi) + ".pdf"

def main():
    count_0 = len(os.listdir(pdfpath))
    ctr = 0 # counter for 'already got'
    for i in range(df.shape[0]):
        # get next DOI
        doi = df.iloc[i]['doi']
        try:
            # URL and download path
            url = doi_download_url(doi)
            filepath = pdfpath + '/' + doi_pdfname(doi)
            # check if we already have this PDF
            if os.path.isfile(filepath):
                ctr += 1
                continue
            # send CURL request
            curl_cmd = f'curl -L -H "Wiley-TDM-Client-Token: {wileyToken}" -D %d-headers.txt {url} -o {filepath}'
            time.sleep(WAITTIME)
            os.system(curl_cmd)
        except:
            continue
    count_1 = len(os.listdir(pdfpath))
    print(f'Already had {ctr}, successfully downloaded {count_1 - count_0} PDFs')
    return 0

###################################################
if __name__ == '__main__':
	main()

# DONE