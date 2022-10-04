#!/usr/local/bin/python

"""
Get DOIs of unread ConBio PDFs from 'links' table; check Wiley path for corresponding PDFs; extract text and
update 'links' table.

E.g.

dbfile="data/master.db"
pdfpath="/Volumes/blitshare/wiley/pdf"

./scrape/read_wiley_pdf_v2.py $dbfile $pdfpath

"""

import os, sys
import re
import fitz
import pdf2txt
#from sqlite3 import IntegrityError
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, Integer, MetaData

# read command line
try:
	dbfile = sys.argv[1];			        del sys.argv[1]
	pdfpath = sys.argv[1];			        del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "db_file pdf_path")
	sys.exit(1)

# parameters
MAXFILES = 500

# open connection to database
engine = create_engine(f'sqlite:///{dbfile}', echo=False)

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
              Column('BADLINK', Integer),
              Column('GOTTEXT', Integer),
              Column('DONEPDF', Integer)
             )

def doi_pdfname(doi):
    return re.sub('/','_', doi) + ".pdf"

def main():
    # create text update list 
    update_list = []
    # select relevant records
    selecter = select(links).\
        where(
            links.c.domain.like('conbio.onlinelibrary.wiley%'),
            links.c.DONEPDF == 0,
            links.c.BADLINK == 0
            )
    # process results
    with engine.connect() as conn:
        result = conn.execute(selecter)
    
        nfiles = 0
        nres = 0
        ngood = 0
        for row in result:
            if nfiles >= MAXFILES:
                break
            nres += 1
            filename = pdfpath + '/' + doi_pdfname(row.doi)
            check = os.path.isfile(filename)
            if check:
                nfiles += 1
                try:
                    # get text
                    pdf_doc = fitz.open(filename)
                    date = pdf2txt.parse_creation_date(pdf_doc)
                    title = pdf2txt.get_title(pdf_doc)
                    nlp = pdf2txt.make_nlp_pipeline()
                    text_list = pdf2txt.get_text(nlp, pdf_doc)
                    abstract = pdf2txt.get_abstract(text_list)
                    # verbose output
                    print()
                    print(date)
                    print(title)
                    print(row.doi)
                    print(abstract)
                    print()
                    # record updates
                    update_list += [{
                        'doivalue': row.doi,
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
                        'doivalue': row.doi,
                        'datevalue': "", 
                        'titlevalue': "",
                        'abstractvalue': "",
                        'pdftextvalue': "",
                        'textflagvalue': 0,
                        'pdfflagvalue': 1,
                        'badlinkvalue': 1
                        }]
                    continue

    # quit if no output
    if update_list == []:
        print(f'Got text from {ngood} out of {nfiles} files from {nres} DOIs')
        return 0
    
    # make update instructions 
    updater = links.update().\
        where(links.c.doi == bindparam('doivalue')).\
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
    # report
    print(f'Got text from {ngood} out of {nfiles} files from {nres} DOIs')

    return 0

if __name__ == '__main__':
    main()

# DONE