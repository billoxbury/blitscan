"""
Get DOIs of unread ConBio PDFs from 'links' table; check Wiley path for corresponding PDFs; extract text and
update 'links' table.

E.g.

pgfile="/Volumes/blitshare/pg/param.txt"
pdfpath="/Volumes/blitshare/data/wiley/pdf"

open -g $AZURE_VOLUME
python3 ./scrape/read_wiley_pdf.py $pgfile $pdfpath
python3 ./read_wiley_pdf.py $pgfile $pdfpath

"""

import os, sys
import re
import pdf2txt
from os.path import isfile
from datetime import datetime
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, Integer, MetaData

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
MAXFILES = 500

# date routines
today = str( datetime.now().date() )

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# create SQL table
metadata_obj = MetaData()
links = Table('links', metadata_obj,
              Column('link', String, primary_key=True),
              Column('domain', String),
              Column('doi', String),
              Column('date', String),
              Column('title', String),
              Column('abstract', String),
              Column('pdftext', String),
              Column('query_date', String),
              Column('search_term', String),
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

def doi_pdfname(doi):
    return re.sub('/','_', doi) + ".pdf"

def main():
    # nlp pipeline
    nlp = pdf2txt.make_nlp_pipeline()
    # create text update list 
    update_list = []
    # select relevant records
    selecter = select(links).\
        where(
            links.c.domain.like('conbio.onlinelibrary.wiley%'),
            links.c.donepdf == 0,
            links.c.badlink == 0
            )
    with engine.connect() as conn:
        result = conn.execute(selecter)
    
    # process results
    nrows = 0
    nfiles = 0
    ngood = 0
    # MAIN LOOP
    for row in result:
        nrows += 1
        # find file
        infile = pdfpath + '/' + doi_pdfname(row.doi)
        check = os.path.isfile(infile)
        if not check:
            continue
        nfiles += 1
        # check file limit
        if nfiles > MAXFILES:
            break
        # proceed to file content/metadata
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
                'doivalue': row.doi,
                'datevalue': date, 
                'titlevalue': title,
                'abstractvalue': abstract,
                'pdftextvalue': '\n'.join(text_list),
                'qdatevalue': today,
                'stermvalue': "wiley_access",
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
                'doivalue': row.doi,
                'datevalue': "", 
                'titlevalue': "",
                'abstractvalue': "",
                'pdftextvalue': "",
                'qdatevalue': today,
                'stermvalue': "wiley_access",
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
            continue
    # END OF MAIN LOOP

    # quit if no output
    if update_list == []:
        print(f'Got text from {ngood} out of {nfiles} files from {nrows} DOIs')
        return 0

    # make update instructions 
    updater = links.update().\
        where(links.c.doi == bindparam('doivalue')).\
        values(
            date = bindparam('datevalue'), 
            title = bindparam('titlevalue'),
            abstract = bindparam('abstractvalue'),
            pdftext = bindparam('pdftextvalue'),
            query_date = bindparam('qdatevalue'),
            search_term = bindparam('stermvalue'),
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

    print(f'Got text from {ngood} out of {nfiles} files from {nrows} DOIs')
    return 0

#############################################################

if __name__ == '__main__':
    main()

# DONE