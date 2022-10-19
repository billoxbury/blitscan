#!/usr/local/bin/python

"""
Performs Bing Custom Search. Reads 'searchterm_file' for next batch of queries, 
runs queries until CSLIMIT reached or response code 429 (daily query allowance exhausted under account policy)
and adds the responses to a temporary data frame. Dedupes data frame and adds new rows to master database.

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.txt"

./scrape/custom_search_bing.py $pgfile


"""

import requests
import os, sys 
import time
import re
from random import choices
from datetime import datetime, timedelta
import numpy as np
import pandas as pd 
from urllib.parse import urlparse
from sqlalchemy import create_engine

# set random number seed
np.random.seed(seed=int(time.time()))
#np.random.seed(seed=1234)

# Bing CS account 
subscriptionKey = os.environ['BING_CUSTOM_SEARCH_SUBSCRIPTION_KEY']
endpoint = os.environ['BING_CUSTOM_SEARCH_ENDPOINT']
customConfigId = os.environ['BING_CUSTOM_CONFIG'] 

# set wait time (days) before query term used again
CSLIMIT = 1000
WAITTIME = 0.01  # time between calls: 1 second on F0 free tier, 0.01 second on S1 standard tier

# how far back in time to allow (6 years)
MAX_DAYS = 2200

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

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# read genus table with species counts 
df_genus = pd.read_sql_table(
    'genera',
    con=engine
)

# date routines
today = str( datetime.now().date() )

# regexes to filter bad links
bad_link_patt = re.compile(r'journalSearch|siteregister|wiley.com/toc|announcements|nature.com.subjects|special_issues/Birds_2021|\.(com|org)[/]?$')
bad_name_patt = re.compile(r'club tours|club news|^forktail|^birdingasia|^birdwatching areas|appendix')

# pdf detection
pdf_patt = re.compile(r"\.pdf$")    
def is_pdf(s):
    return bool(pdf_patt.search(s))

# search terms
def make_search_terms(k = CSLIMIT, correction = 0):
    '''
    sample genus with probability weights 'vu_count + correction' from the dataframe 'df_genus' 
    By default correction = 0, but setting > 0 allows LC genera to be included as well
    '''
    searchpop = df_genus['genus']
    weights = df_genus['vu_count']
    sample = choices(searchpop, weights, k = k)
    return list(set(sample))

# main loop
def get_responses(searchterms):
    # initialise data frame
    df = pd.DataFrame(columns = ['date',
                                'link',
                                'link_name',
                                'snippet',
                                'language',
                                'domain',
                                'pdf_link',
                                'search_term',
                                'query_date'])
    good_ctr = 0 # count good links
    bad_ctr = 0  # count bad links
    # loop over query terms
    ctr = len(searchterms)
    for w in searchterms:    
        search_term = w + "+(bird+species)"
        get_string = endpoint + "/v7.0/custom/search?" \
                                + "&sort=date&q=" + search_term \
                                + "&customconfig=" + customConfigId
        response = requests.get(get_string,
                                headers = {'Ocp-Apim-Subscription-Key': subscriptionKey})
        # wait 1 second under Bing free tier
        time.sleep(WAITTIME)

        # check response code
        if response.status_code == 429 or ctr < 1: 
            print(f'{ctr}: {w}')
            break
        if response.status_code != 200:
            continue
        
        # if OK
        ctr -= 1   
        ret = response.json()
        try:
            items =  ret['webPages']['value']
            print(f'{ctr}: {len(items)} {w}')
            # loop through the items
            for item in items:
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
                    # if too old, skip
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
                else:
                    date = None
                    
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
                                
                row = pd.DataFrame({
                        'date': [date],
                        'link': [link],
                        'link_name': [link_name],
                        'snippet': [snippet],
                        'language': [language],
                        'pdf_link': [pdf_link],
                        'domain': [domain],
                        'search_term': [w],
                        'query_date': [today]
                        })
                df = pd.concat([df, row], ignore_index = True, axis = 0)
                good_ctr += 1
            # END loop through the items
        except:
            print(f'Response {response.status_code}: 0 {w}')
    # END loop over query terms
    print(f"Processed {CSLIMIT} responses")
    print(f'Found {good_ctr} good links, {bad_ctr} bad links')
    df = df.drop_duplicates()
    print(f'Outputting {df.shape[0]} distinct records') 
    return df

# write to disk
def write_to_database(df):
    # check for links already in the database
    dups = []
    for i in range(df.shape[0]):
        link = df.at[i,'link']
        ct = engine.execute(f'SELECT count(*) FROM links WHERE link LIKE \'{link}\'').fetchall()[0][0]
        if ct > 0: 
            dups += [i]
    # ... and remove these
    df = df.drop(dups, axis=0)
    print(f'Dropped {len(dups)} records already in database, adding {df.shape[0]} new')
    # add additional fields
    df['BADLINK'] = 0
    df['DONEPDF'] = 0
    df['GOTTEXT'] = 0
    df['GOTSCORE'] = 0
    df['GOTSPECIES'] = 0
    df['GOTTRANSLATION'] = 0
    df['DONECROSSREF'] = 0
    # ... and add to database
    df.to_sql(
        'links', # name of SQL table
        engine, # sqlalchemy.engine.Engine or sqlite3.Connection
        if_exists = 'append', # how to behave if the table already exists
        index = False, # set False to ignore the index of DataFrame
)

def main():
    searchterms = make_search_terms()
    print(f"Read {len(searchterms)} search terms")
    df = get_responses(searchterms)
    write_to_database(df)
    return 0

if __name__ == '__main__':
	main()

# DONE