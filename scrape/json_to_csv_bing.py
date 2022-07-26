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

import sys
import json
import re
import pandas as pd
from datetime import datetime, timedelta
from urllib.parse import urlparse


# how far back in time to allow (3 years)
MAX_DAYS = 2200

# read command line
try:
	qfile = sys.argv[1];			del sys.argv[1]
	csvfile = sys.argv[1];			del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "json_file csv_file")
	sys.exit(1)

# get raw query data
with open(qfile, 'r') as qf:
    data = json.load(qf)
qf.close()
print("Read json data with %d keys" % len(data))

# read current data frame
df = pd.read_csv(csvfile, index_col = None).fillna('')
print("Read %d csv records" % df.shape[0])

# store list of known links
known_links = list(df['link']) + list(df['pdf_link'])
known_links = list(set(known_links))

# today's date
today = str( datetime.now().date() )

# regexes to filter bad links
bad_link_patt = re.compile(r'journalSearch|siteregister|wiley.com/toc|announcements|nature.com.subjects|special_issues/Birds_2021|\.(com|org)[/]?$')
bad_name_patt = re.compile(r'club tours|club news|^forktail|^birdingasia|^birdwatching areas|appendix')

# pdf detection
pdf_patt = re.compile(r"\.pdf$")    
def is_pdf(s):
    return bool(pdf_patt.search(s))

def initial_data_check():
    all_items = []
    for w in data:
        for d in data[w]:
            all_items += data[w][d]
    distinct_items = [json.loads(it) for it in list(set([json.dumps(it) for it in all_items])) ]
    print("Total nr items:", len(all_items))
    print("Nr distinct items:", len(distinct_items))

# build/update data frame
def build_data_frame(data):
    
    global df
    good_ctr = 0
    bad_ctr = 0 
    for w in data:
        for d in data[w]:
            
            # skip if [w,d] already in the database
            wlist = list(df['search_term'].isin([w]))
            dlist = list(df['query_date'].isin([d]))
            checker = [a and b for a, b in zip(wlist, dlist)]
            if True in checker: continue
            
            # read list of items
            response = data[w][d]
            
            # loop through the items
            for item in response:
                
                if 'url' in item:
                    link = item['url']
                    domain = urlparse(link).netloc
                else:
                    bad_ctr += 1
                    continue
                # skip if bad link
                if bool( bad_link_patt.search(link) ):
                    bad_ctr += 1
                    continue
                
                if 'datePublished' in item:
                    date = item['datePublished'].split('T')[0]
                    # if older than 3 years, skip
                    try:
                        date_n = datetime.strptime(date, "%Y-%b-%d")
                        if date_n < datetime.now() - timedelta(days = MAX_DAYS):
                            bad_ctr += 1
                            continue
                    except:
                        try:
                            date_n = datetime.strptime(date, "%Y-%m-%d")
                            if date_n < datetime.now() - timedelta(days = MAX_DAYS):
                                bad_ctr += 1
                                continue
                        except:
                            date = None
                            #bad_ctr += 1
                            #continue
                else:
                    date = None
                    #bad_ctr += 1
                    #continue
                    
                if 'name' in item:
                    link_name = item['name']
                else:
                    link_name = None
                # skip if bad link name    
                if bool(bad_name_patt.search(link_name.lower())):
                    bad_ctr += 1
                    continue
                
                if 'snippet' in item:
                    snippet = item['snippet']
                else:
                    snippet = None
                if 'language' in item:
                    language = item['language']
                else:
                    language = None
                
                if 'deepLinks' in item:
                    for lk in item['deepLinks']:
                        lk_url = lk['url']
                        if is_pdf(lk_url):
                            pdf_link = lk_url
                elif is_pdf(link):
                    pdf_link = link
                else:
                    pdf_link = None
                                
                row = pd.DataFrame({'date': [date],
                       'link': [link],
                       'link_name': [link_name],
                       'snippet': [snippet],
                       'language': [language],
                       'title': [""],
                       'abstract': [""],
                       'pdf_link': [pdf_link],
                       'domain': [domain],
                       'search_term': [w],
                       'query_date': [d],
                       'BADLINK': [0],
                       'DONEPDF': [0],
                       'GOTTEXT': [0],
                       'GOTSCORE': [0],
                       'GOTSPECIES': [0]})
                df = pd.concat([df, row], ignore_index = True, axis = 0)
                good_ctr += 1
    return [good_ctr, bad_ctr]

def dedupe_rows():
    """
    dedupe - many links will have been returned in more than one search
    """ 
    global df
    before = df.shape[0]
    df = df.drop_duplicates(subset = ['link'], keep = 'first')
    after = df.shape[0]
    return [before, after]

def write_to_disk():
   # write to disk
   df.to_csv(csvfile, index = False)
   print("Updated data frame written to %s" % csvfile)
 
def main():
    initial_data_check()
    good, bad = build_data_frame(data)
    print(f'Processed {good} rows, {bad} rejected')  

    before, after = dedupe_rows() 
    print(f'Deduping on link reduced {before} to {after} rows')
    write_to_disk()
    return 0

if __name__ == '__main__':
	main()

# DONE