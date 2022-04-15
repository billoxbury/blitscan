#!/usr/local/bin/python

"""
Parses JSON file of responses and builds CSV of key fields
 - date
 - link
 - [title]
 - [abstract]
 - pdf_link
 - file_format
 - domain
 - search_term
 - query_date

[Title/abstract are not included at this stage but are left for 'cs_get_text.R']

This script does not overwrite the existing 'master.csv' - rather it outputs to a file
'master-YYYY-MM-DD.csv' (with today's date). This is then saved to 'master.csv' at a later stage.

E.g. 

qfile="data/google/cs_queries.json"
csvfile="data/google/master.csv"

./scrape/json_to_csv.py $qfile $csvfile
"""

import os, sys
import json
import re
import pandas as pd
from pathlib import Path
from datetime import datetime, timedelta

# read command line
try:
	qfile = sys.argv[1];			del sys.argv[1]
	infile = sys.argv[1];			del sys.argv[1]	
	outfile = sys.argv[1];			del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "json_file csv_file")
	sys.exit(1)

# get raw query data
with open(qfile, 'r') as qf:
    data = json.load(qf)
qf.close()
print("Read json data with %d keys" % len(data))

# read current data frame
df = pd.read_csv(infile, index_col = None).fillna('')
print("Read %d csv records" % df.shape[0])

# store list of known links
known_links = list(df['link']) + list(df['pdf_link'])
known_links = list(set(known_links))

# how far back in time to allow (3 years)
MAX_DAYS = 1100

# today's date
today = str( datetime.now().date() )

# regexes to filter bad links
patt = re.compile(r'journalSearch|siteregister|wiley.com/toc|core/books|/issue/|announcements|nature.com.subjects|special_issues/Birds_2021|\.(com|org)[/]?$')
is_pdf = re.compile(r"PDF|pdf")

# for later use
distinct_items = []
pm_items = []

def initial_data_check():
    global distinct_items

    query_items = dict()
    for k in data:
        query_items[k] = sum([data[k][d]['items'] for d in data[k].keys() if 'items' in data[k][d]], [])
    #empty_k = [k for k in data.keys() if len(query_items[k]) == 0]
    # search terms returning no items: 
    #print("Queries returning no items:")
    #for k in empty_k:
    #    print(f'\t{k}')
    # set of all distinct items:
    all_items = sum(query_items.values(), [])
    distinct_items = [json.loads(it) for it in list(set([json.dumps(it) for it in all_items])) ]
    print("Total nr items:", len(all_items))
    print("Nr distinct items:", len(distinct_items))

def print_dict(d):
    lst = sorted(d.items(), key=lambda item: -item[1])
    for (t,g) in lst:
        print(f'\t{g:2.4f} {t:20}')

def scan_item_keys():
    # report occurence of 'item' keys
    item_keys = list(set(sum([list(it.keys()) for it in distinct_items],[])))
    tmp = dict()
    for k in item_keys:
        tmp[k] = len([it for it in distinct_items if k in it.keys()]) / len(distinct_items)
    print("Item keys:")
    print_dict(tmp)

def scan_pagemap_keys():
    global pm_items
    # report occurent of 'pagemap' keys
    pm_items = [it for it in distinct_items if 'pagemap' in it.keys()]
    pm_keys = list(set(sum([list(it['pagemap'].keys()) for it in pm_items],[])))
    tmp = dict()
    for k in pm_keys:
        tmp[k] = len([it for it in pm_items 
                        if k in it['pagemap'].keys()]) / len(pm_items) 
    print("Keys of 'pagemap':")    
    print_dict(tmp)

def scan_metatags_keys():
    # report occurence of 'metatags' keys
    mt_items = [it for it in pm_items if 'metatags' in it['pagemap']]
    mt_keys = list(set(sum([list(it['pagemap']['metatags'][0]) for it in mt_items],[])))
    tmp = dict()
    for k in mt_keys:
        tmp[k] = len([it for it in mt_items 
                        if k in it['pagemap']['metatags'][0]]) / len(mt_items)
    print("Keys of 'metatags':")
    print_dict(tmp)

# function to extract publication date from 'htmlSnippet'
def extract_date(snippet):
    try:
        txt = snippet.split('<b>')[0].strip()
        part = txt.split(' ')
        if part[2] == 'ago':
            ago = int(part[0])
            return str( datetime.now().date() - timedelta(days = ago) )
        else:
            return (part[2] + "-" + part[0] + "-" + part[1]).strip(',')
    except:
        return None

# build/update data frame
def build_data_frame(data):
    global df
    ctr = 0
    for w in data:
        for d in data[w]:
            
            # skip if [w,d] already in the database
            wlist = list(df['search_term'].isin([w]))
            dlist = list(df['query_date'].isin([d]))
            checker = [a and b for a, b in zip(wlist, dlist)]
            if True in checker: continue
            
            # otherwise get http response
            response = data[w][d]
            if 'items' not in response.keys(): continue
            for item in data[w][d]['items']:
                # restrict to items with 'pagemap' and 'metatags'
                if 'pagemap' not in item.keys(): continue
                if 'metatags' not in item['pagemap'].keys(): continue
                
                if 'htmlSnippet' in item:
                    date = extract_date(item['htmlSnippet'])
                    # if older than 3 years, skip
                    try:
                        date_n = datetime.strptime(date, "%Y-%b-%d")
                        if date_n < datetime.now() - timedelta(days = MAX_DAYS):
                            continue
                    except:
                        try:
                            date_n = datetime.strptime(date, "%Y-%m-%d")
                            if date_n < datetime.now() - timedelta(days = MAX_DAYS):
                                continue
                        except:
                            date = None               
                else: 
                    date = None
            
                if 'link' in item: 
                    link = item['link']
                else: 
                    link = None 
                # have we seen this link before? if so, skip
                if link in known_links:
                    continue         
                # otherwise proceed
                if 'displayLink' in item: 
                    domain = item['displayLink']
                else: 
                    domain = None
                if 'fileFormat' in item: 
                    file_format = item['fileFormat']
                else: 
                    """
                    flagged as 'HTML' by default because 'fileFormat' not present - 
                    but this needs checking later because it may be PDF
                    """
                    file_format = 'HTML'
                if 'citation_pdf_url' in item['pagemap']['metatags'][0]:
                    pdf_link = item['pagemap']['metatags'][0]['citation_pdf_url']
                else:
                    pdf_link = None

                row = {'date': date,
                       'link': link,
                       'title': "",
                       'abstract': "",
                       'pdf_link': pdf_link,
                       'file_format': file_format,
                       'domain': domain,
                       'search_term': w,
                       'query_date': d,
                       'BADLINK': 0,
                       'DONEPDF': 0,
                       'GOTTEXT': 0,
                       'GOTSCORE': 0,
                       'GOTSPECIES': 0}
                df = df.append(row, ignore_index = True)

def drop_bad_rows():
    """ 
    drop bad rows - first, links to general pages rather than specific articles; 
    second, items in PDF file format who's link is already present as pdf_link 
    for another item 
    """
    global df
    bad_rows = []
    pdf_links = list(df['pdf_link'])
    for i in range(df.shape[0]):
        link = df.iloc[i]['link']
        ff = df.iloc[i]['file_format']
        if bool( patt.search(link) ):
            bad_rows += [i]
        if bool( is_pdf.search(ff) ) and link in pdf_links:
            bad_rows += [i]
    bad_rows = list(set(bad_rows))
    df = df.drop(bad_rows)
    print("Removed %d bad or redundant links" % len(bad_rows))
    """
    dedupe - many links will have been returned in more than one search
    """ 
    df = df.drop_duplicates(subset = ['link'], keep = 'first')
    print("Built data frame with %d rows, %d columns" % (df.shape[0], df.shape[1]))

def write_to_disk():
   # write to disk
   df.to_csv(outfile, index = False)
   print("Updated data frame written to %s" % outfile)
 
def main():
    initial_data_check()
    #scan_item_keys()
    #scan_pagemap_keys()
    #scan_metatags_keys()
    build_data_frame(data)
    drop_bad_rows() 
    write_to_disk()    
    return 0

if __name__ == '__main__':
	main()

# DONE