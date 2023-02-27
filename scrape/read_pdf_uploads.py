"""
Processses manually uploaded PDF files  adds relevant details to the database.

E.g.

pgfile="/Volumes/blitshare/pg/param.txt"
pdfpath="/Volumes/blitshare/data/pdf"
#pdfpath="../dev/pdf-samples"
wwwpath="webapp/www/upload"

open -g $AZURE_VOLUME
python3 ./scrape/read_pdf_uploads.py $pgfile $pdfpath $wwwpath

"""

import os, sys
import re
import pdf2txt
from os import listdir
from os.path import isfile, join
from datetime import datetime
from sqlalchemy import create_engine, select, update, insert, bindparam
from sqlalchemy import Table, Column, String, Integer, MetaData

# read command line
try:
	pgfile = sys.argv[1];			        del sys.argv[1]
	pdfpath = sys.argv[1];			        del sys.argv[1]
	wwwpath = sys.argv[1];			        del sys.argv[1]
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

# constants
pdf_patt = re.compile('\.pdf$')
outpath = join(pdfpath, 'out')

# date routines
today = str( datetime.now().date() )

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# create SQL tables
metadata_obj = MetaData()
links = Table('links', metadata_obj,
              Column('link', String, primary_key=True),
              Column('date', String),
              Column('title', String),
              Column('abstract', String),
              Column('pdftext', String),
              Column('language', String),
              Column('query_date', String),
              Column('search_term', String),
              Column('domain', String),
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

# find files to process
filelist = [f for f in listdir(pdfpath) if isfile(join(pdfpath, f)) and bool(pdf_patt.search(f))]

def get_local_list():
    '''
    get current list of local files
    ''' 
    local_list = []
    selecter = select(links).\
        where(
            links.c.domain == 'local',
            )
    with engine.connect() as conn:
        uploads = conn.execute(selecter)
    for row in uploads:
        local_list += [row.link.lstrip("upload/")]
    return local_list

def main():
    # check we have files to process
    if len(filelist) == 0:
        print('No uploads found')
        return 0

    # otherwise proceed - get filenames already in the database
    local_list = get_local_list()   

    # set NLP pipeline
    nlp = pdf2txt.make_nlp_pipeline()

    # initialise for main loop
    update_list = []
    nfiles = 0
    ngood = 0

    # main loop
    for file in filelist:
        # check next file
        if file in local_list:
            continue
        infile = join(pdfpath, file)
        if not isfile(infile):
            continue

        # check file limit
        if nfiles >= MAXFILES:
            break
        else:
            # set outfile locations
            wwwfile = join(wwwpath, file)
            outfile = join(outpath, file)
            print(f'Processing {infile}')
            nfiles += 1
        # proceed to file content/metadata
        try:
            link = 'upload/' + file
            date = pdf2txt.parse_creation_date(infile)
            title = pdf2txt.get_title(infile)
            text_list = pdf2txt.get_text(nlp, infile)
            if title == "":
                title = pdf2txt.guess_title(text_list)
            abstract = pdf2txt.guess_abstract(text_list)
            # verbose output
            print(date)
            print(link)
            print('--->')
            print(abstract)
            print()
            # record updates
            update_list += [{
                'linkvalue': link,
                'datevalue': date, 
                'titlevalue': title,
                'abstractvalue': abstract,
                'pdftextvalue': '\n'.join(text_list),
                'qdatevalue': today,
                'stermvalue': "file_upload",
                'domainvalue': "local",
                'langvalue': '',
                # flags:
                'textflagvalue': 1,
                'scoreflagvalue': 0,
                'speciesflagvalue': 0,
                'transflagvalue': 1,
                'crflagvalue': 0,
                'dateflagvalue': 1,
                'pdfflagvalue': 1,
                'badlinkvalue': 0
            }]
            ngood += 1
        except:
            print(f'Broken file {infile}') 
        # move file to out-tray
        res1 = os.system(f'cp {infile} {wwwfile}')
        res2 = os.system(f'mv {infile} {outfile}')
        res3 = os.system(f'chmod 644 {wwwpath}/*')
    # END OF main loop

    # quit if no output
    if update_list == []:
        print(f'Got text from {ngood} out of {nfiles} files')
        return 0
        
    # make update instructions 
    updater = links.insert().\
        values(
            link = bindparam('linkvalue'),
            date = bindparam('datevalue'), 
            title = bindparam('titlevalue'),
            abstract = bindparam('abstractvalue'),
            pdftext = bindparam('pdftextvalue'),
            language = bindparam('langvalue'),
            query_date = bindparam('qdatevalue'),
            search_term = bindparam('stermvalue'),
            domain = bindparam('domainvalue'),
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
    # report
    print(f'Got text from {ngood} out of {nfiles} files')
    return 0

#############################################################

if __name__ == '__main__':
    main()

# DONE
