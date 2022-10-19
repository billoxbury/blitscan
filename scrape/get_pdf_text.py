#!/usr/local/bin/python

"""
Get unread pdf_links from 'links' table; attempt to download to tmp folder; extract text and
update 'links' table; delete PDF.


E.g.

pgfile="/Volumes/blitshare/pg/param.R"
pdfpath="data/tmp"

./scrape/get_pdf_text.py $pgfile $pdfpath

"""

import os, sys
import re
import fitz
import requests
import pdf2txt
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, Integer, MetaData
from datetime import datetime

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

# parameters
MAXCALLS = 100
MAXFNAMESIZE = 128

#  global constants - filename regex
fn_patt = re.compile(" |=|\?|\:|/|\.")

# PDF download functions
def download_path(url):
    filename = fn_patt.sub('_', url)[-MAXFNAMESIZE:] + ".pdf"
    return f'{pdfpath}/{filename}'

def run_download(url):
    """
    return code:
    0 success
    -1 file already exists
    -2 download failure
    """
    # set filename/path and check if it already exists
    dp = download_path(url)
    if os.path.exists(dp): 
        return -1
    # attempt to download pdf
    try: 
        download = requests.get(url, allow_redirects=True)
    except:
        return -2
    # if successful, write pdf to disk
    with open(dp, 'wb') as ptr:
        ptr.write(download.content)
    return 0

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# create SQL tables
metadata_obj = MetaData()
links = Table('links', metadata_obj,
              Column('pdf_link', String, primary_key=True),
              Column('domain', String),
              Column('date', String),
              Column('title', String),
              Column('abstract', String),
              Column('pdftext', String),
              Column('BADLINK', Integer),
              Column('GOTTEXT', Integer),
              Column('DONEPDF', Integer)
             )
domains = Table('domains', metadata_obj,
              Column('domain', String),
              Column('minable', Integer),
             )

def main():
    # initialise counters
    totalcalls = 0
    ngood = 0

    # make NLP model/pipeline
    nlp = pdf2txt.make_nlp_pipeline()

    # select minable domains
    domain_selecter = select(domains).\
        where(domains.c.minable == 1)

    # get domains from database
    with engine.connect() as conn:
        domain_set = conn.execute(domain_selecter)
    # loop over domains 
    for drow in domain_set:
        thisdomain = drow.domain    
        print(f'Domain {thisdomain} ...')
        # initialise update list for this domain
        update_list = []
        # get links for this domain
        link_selecter = select(links).\
            where(
                links.c.domain.like(f'%{thisdomain}%'),
                links.c.BADLINK == 0,
                links.c.DONEPDF == 0,
                links.c.pdf_link != None
            )
        # loop over links for this domain
        ncalls = 0
        with engine.connect() as conn:
            link_set = conn.execute(link_selecter)
        for lrow in link_set:
            # check how many calls made to this domain
            if ncalls >= MAXCALLS:
                totalcalls += ncalls
                break
            # download file
            dp = download_path(lrow.pdf_link)
            res = run_download(lrow.pdf_link)
            ncalls += 1
            print(f'{res} {dp}')
            # get text from file
            try:
                pdf_doc = fitz.open(dp)
            except:
                update_list += [{
                        'pdfvalue': lrow.pdf_link,
                        'datevalue': lrow.date, 
                        'titlevalue': lrow.title,
                        'abstractvalue': lrow.abstract,
                        'pdftextvalue': "",
                        'textflagvalue': lrow.GOTTEXT,
                        'pdfflagvalue': 0,
                        'badlinkvalue': 1
                        }]
                continue
            try:
                date = pdf2txt.parse_creation_date(pdf_doc)
                text_list = pdf2txt.get_text(nlp, pdf_doc)
                # keep title/abstract if already got them from HTML
                if lrow.GOTTEXT == 1:
                    title = lrow.title
                    abstract = lrow.abstract
                else:
                    title = pdf2txt.get_title(pdf_doc)
                    abstract = pdf2txt.get_abstract(text_list)
                # verbose output
                print()
                print(f'{ncalls}: {dp}')
                print(date)
                print(title)
                print()
                print(abstract)
                print()
                # record updates
                update_list += [{
                            'pdfvalue': lrow.pdf_link,
                            'datevalue': date, 
                            'titlevalue': title,
                            'abstractvalue': abstract,
                            'pdftextvalue': '\n'.join(text_list),
                            'textflagvalue': 1,
                            'pdfflagvalue': 1,
                            'badlinkvalue': 0
                            }]
                ngood += 1
            except:
                update_list += [{
                        'pdfvalue': lrow.pdf_link,
                        'datevalue': lrow.date, 
                        'titlevalue': lrow.title,
                        'abstractvalue': lrow.abstract,
                        'pdftextvalue': "",
                        'textflagvalue': lrow.GOTTEXT,
                        'pdfflagvalue': 1,
                        'badlinkvalue': lrow.BADLINK
                        }]
                continue
            totalcalls += ncalls
            # END OF __for lrow in link_set__

        # skip to next domain if no output
        if update_list == []:
            continue
            
        # make update instructions to capture data this domain
        updater = links.update().\
                where(links.c.pdf_link == bindparam('pdfvalue')).\
                values(
                    date = bindparam('datevalue'), 
                    title = bindparam('titlevalue'),
                    abstract = bindparam('abstractvalue'),
                    pdftext = bindparam('pdftextvalue'),
                    GOTTEXT = bindparam('textflagvalue'),
                    DONEPDF = bindparam('pdfflagvalue'),
                    BADLINK = bindparam('badlinkvalue')  
                    )
        # ... and commit to remote table
        with engine.connect() as conn:
            conn.execute(updater, update_list)

        # clean up ...
        os.system(f'rm {pdfpath}/*')
        # END OF __for drow in domain_set__

    # ... and report
    print(f'Got text from {ngood} files out of {totalcalls} requests')
    return 0

if __name__ == '__main__':
    main()

# DONE