"""
Get unread pdf_links from 'links' table; attempt to download to tmp folder; extract text and
update 'links' table; delete PDF.


E.g.

pgfile="/Volumes/blitshare/pg/param.txt"
pdfpath="data/tmp"

./scrape/get_pdf_text.py $pgfile $pdfpath

"""

import os, sys
import re
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
              # flags:
              Column('badlink', Integer),
              Column('gottext', Integer),
              Column('gotscore', Integer),
              Column('gotspecies', Integer),
              Column('gottranslation', Integer),
              Column('donepdf', Integer),
              Column('donecrossref', Integer),
              Column('datecheck', Integer)
             )
domains = Table('domains', metadata_obj,
              Column('domain', String),
              Column('minable', Integer),
             )

def main():
    # initialise counters
    totalcalls = 0
    totalfiles = 0
    totalgood = 0

    # make NLP model/pipeline
    nlp = pdf2txt.make_nlp_pipeline()

    # select minable domains
    domain_selecter = select(domains).\
        where(domains.c.minable == 1)

    # get domains from database
    with engine.connect() as conn:
        domain_set = conn.execute(domain_selecter)
    # LOOP over domains 
    for drow in domain_set:
        thisdomain = drow.domain    
        print(f'Domain {thisdomain} ...')
        # initialise update list for this domain
        update_list = []
        # get links for this domain
        link_selecter = select(links).\
            where(
                links.c.domain.like(f'%{thisdomain}%'),
                links.c.badlink == 0,
                links.c.donepdf == 0,
                links.c.pdf_link != None
            )
        # LOOP over links for this domain
        ncalls = 0
        nfiles = 0
        ngood = 0
        with engine.connect() as conn:
            link_set = conn.execute(link_selecter)
        for lrow in link_set:
            # check how many calls made to this domain
            if ncalls >= MAXCALLS:
                totalcalls += ncalls
                totalfiles += nfiles
                break
            # download file
            pdflink = lrow.pdf_link
            infile = download_path(pdflink)
            res = run_download(pdflink)
            ncalls += 1
            # skip if not got new file
            if res < 0:
                continue
            nfiles += 1
            # get text from file
            try:
                date = pdf2txt.parse_creation_date(infile)
                title = pdf2txt.get_title(infile)
                text_list = pdf2txt.get_text(nlp, infile)
                if title == "":
                    title = pdf2txt.guess_title(text_list)
                abstract = pdf2txt.guess_abstract(text_list)
                # verbose output
                print(date)
                print(title)
                print('--->')
                print(abstract)
                print()
                ngood += 1
                # record updates
                update_list += [{
                    'pdflinkvalue': pdflink,
                    'datevalue': date, 
                    'titlevalue': title,
                    'abstractvalue': abstract,
                    'pdftextvalue': '\n'.join(text_list),
                    # flags:
                    'textflagvalue': 1,
                    'scoreflagvalue': 0,
                    'speciesflagvalue': 0,
                    'transflagvalue': 0,
                    'crflagvalue': 0,
                    'dateflagvalue': 1,
                    'pdfflagvalue': 1,
                    'badlinkvalue': 0
                }]
            except:
                update_list += [{
                    'pdflinkvalue': pdflink,
                    'datevalue': "", 
                    'titlevalue': "",
                    'abstractvalue': "",
                    'pdftextvalue': "",
                    # flags:
                    'textflagvalue': 0,
                    'scoreflagvalue': 0,
                    'speciesflagvalue': 0,
                    'transflagvalue': 0,
                    'crflagvalue': 0,
                    'dateflagvalue': 0,
                    'pdfflagvalue': 1,
                    'badlinkvalue': 1
                }]
        # END OF LOOP over links for this domain
        print(f'{thisdomain}: {ngood} texts, {nfiles} files, {ncalls} rows')
        totalcalls += ncalls
        totalfiles += nfiles
        totalgood += ngood

        # skip to next domain if no output
        if update_list == []:
            continue
    
        # else make update instructions to capture data for this domain
        updater = links.update().\
                where(links.c.pdf_link == bindparam('pdflinkvalue')).\
                values(
                    date = bindparam('datevalue'), 
                    title = bindparam('titlevalue'),
                    abstract = bindparam('abstractvalue'),
                    pdftext = bindparam('pdftextvalue'),
                    # flags:
                    gottext = bindparam('textflagvalue'),
                    gotscore = bindparam('scoreflagvalue'),
                    gotspecies = bindparam('speciesflagvalue'),
                    gottranslation = bindparam('transflagvalue'),
                    donepdf = bindparam('pdfflagvalue'),
                    badlink = bindparam('badlinkvalue'),
                    donecrossref = bindparam('crflagvalue'),
                    datecheck = bindparam('dateflagvalue')
                    )        
        # ... and commit to remote table
        with engine.connect() as conn:
            conn.execute(updater, update_list)
            conn.commit()

        # clean up ...
        os.system(f'rm {pdfpath}/*')
    # END OF LOOP over domains 

    # ... and report
    print(f'Got {totalgood} texts from {totalfiles} files out of {totalcalls} rows')
    return 0

#############################################################

if __name__ == '__main__':
    main()

# DONE