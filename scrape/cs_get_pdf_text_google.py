#!/usr/local/bin/python

"""
Take CSV file containing fields 'link', 'pdf_link', 'title', 'abstract', 'file_format'

For each record, if titel/abstract not already populated, download PDF file and extract title/abstract from
it, writing back to the CSV.
"""

import sys
import pandas as pd
import spacy
from spacy.matcher import Matcher                                                                                                                                                                                         
import os
import re
import requests
import fitz
from pathlib import Path

TITLE_MIN_WORDS = 3
TMP_PATH = "data/pdf/tmp"
MAXFNAMESIZE = 128
MAXCALLS = 256

# read command line
try:
	csvfile = sys.argv[1];			del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "csv_file")
	sys.exit(1)


# initialise
df = pd.read_csv(csvfile, index_col = None).fillna('')
nlp = spacy.load('en_core_web_md') 
nlp.add_pipe('sentencizer')


# functions
def get_title(pdf_doc):
    if 'title' in pdf_doc.metadata:
        return pdf_doc.metadata['title']
    elif len(pdf_doc.get_toc()) > 0:
        return pdf_doc.get_toc()[0][1]
    else:
        return ''

def make_sentence_list(nlp_doc):
    sentences = list(nlp_doc.sents)
    return sentences

def verbs(sent):
    pattern=[
        {'POS': 'VERB', 'OP': '?'},
        {'POS': 'ADV', 'OP': '*'},
        {'POS': 'VERB', 'OP': '+'}
    ]
    # instantiate a Matcher instance
    matcher = Matcher(nlp.vocab) 
    # add pattern to matcher
    matcher.add('verb-phrases', [pattern])
    d = nlp(sent.text)
    # call the matcher to find matches 
    matches = matcher(d)
    spans = [d[start:end] for _, start, end in matches] 
    return spans

def clean_sentences(sents):
    sentences = [s for s in sents if len(verbs(s)) > 0 and
                    len(s) > 3]
    return sentences

def get_abstract(pdf_doc, sentence_threshold = 2):
    pages = [pdf_doc[i].get_text('blocks') for i in range(pdf_doc.page_count)]
    all_blocks = sum(pages, [])
    for b in all_blocks:
        doc = nlp(b[4])
        sents = clean_sentences(
            make_sentence_list(doc)
            )
        if len(sents) > sentence_threshold:
            abstract = b[4]
            break
    return abstract


def main():
    global df
    global MAXCALLS
    n = df.shape[0]

    pdf_patt = re.compile("PDF")
    ms_patt = re.compile("^Micro[S|s]oft")
    fn_patt = re.compile(" |=|\?|\:|/|\.")

    bad_rows = []
    known_titles = list(set( list(df['title']) ))

    for i in range(df.shape[0]):

        if MAXCALLS <= 0:
            break
        # check flags
        if df.at[i,'BADLINK'] == 1 or df.at[i,'GOTTEXT'] == 1 or df.at[i,'DONEPDF'] == 1:
            continue

        # set variables
        link = df.at[i,'link']
        pdflink = df.at[i,'pdf_link']
        title = df.at[i,'title']
        abstract = df.at[i,'abstract']
        file_format = df.at[i,'file_format']
        
        # check if we already have title/abstract
        #if (len(title) > 0 and len(abstract) > 0):
        #    continue
            
        # skip if Microsoft Word or Excel
        if bool(ms_patt.search(file_format)): 
            bad_rows += [i]
            continue
            
        # if OK, check for a suitable pdf link
        if bool(pdf_patt.search(file_format)):
            pdflink = link
        
        # set filename/path and check if it already exists
        filename = fn_patt.sub('_', link)[-MAXFNAMESIZE:] + ".pdf"
        download_path = f'{TMP_PATH}/{filename}'
        remove = f'rm {download_path}'
        if os.path.exists(download_path): 
            continue
        
        # attempt to download pdf
        MAXCALLS -= 1
        try: 
            download = requests.get(pdflink, allow_redirects=True)
        except:
            print(f"{MAXCALLS} {i}: {df.at[i, 'domain']}  connection failure")
            sys.stdout.flush()
            continue
        if download.status_code != 200:
            print(f"{MAXCALLS} {i}: {df.at[i, 'domain']} status {download.status_code}")
            sys.stdout.flush()
            continue
    
        # if successful, download pdf
        with open(download_path, 'wb') as ptr:
            ptr.write(download.content)
        
        # and read pdf file
        infile = Path(download_path)
        try:
            pdf_doc = fitz.open(infile)
            # set title
            pdf_title = get_title(pdf_doc)
            if len(pdf_title) > 1 and pdf_title in known_titles:
                bad_rows += [i]
                print(f"{MAXCALLS} {i}:  {df.at[i, 'domain']} ALREADY SEEN {pdf_title}")
                sys.stdout.flush()
                os.system(remove)                
                continue
            if bool(ms_patt.search(pdf_title)) or len(pdf_title.split()) < TITLE_MIN_WORDS:
                bad_rows += [i]
                df.at[i,'title'] = pdf_title
                print(f"{MAXCALLS} {i}:  {df.at[i, 'domain']} BADLINK {pdf_title}")
                sys.stdout.flush()
                os.system(remove)                
                continue

            df.at[i,'title'] = pdf_title
            print(f'{MAXCALLS} {i}: {pdf_title}')
            sys.stdout.flush()
            # add to known titles
            if pdf_title != '':
                known_titles += [pdf_title]
            # set abstract
            pdf_abstract = get_abstract(pdf_doc)
            if len(pdf_abstract.split()) > 2:
                df.at[i,'abstract'] = pdf_abstract
                # set 'done' flags
                df.at[i, 'GOTTEXT'] = 1
                df.at[i, 'DONEPDF'] = 1
            # delete file
            os.system(remove)
        except:
            df.at[i,'abstract'] = ''
            print(i, "bad row")
            sys.stdout.flush()
            bad_rows += [i]
            #os.system(remove)
            print(f"{MAXCALLS} {i}:  {df.at[i, 'domain']} failed to get abstract")
            sys.stdout.flush()
            continue
    # clean up
    print(f'Flagging {len(bad_rows)} bad rows')
    df.at[bad_rows, 'BADLINK'] = 1
    # write to disk
    df.to_csv(csvfile, index = False)
    print(f"Done and written to {csvfile}")

if __name__ == '__main__':
	main()

# DONE