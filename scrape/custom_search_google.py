#!/usr/local/bin/python

"""
Performs Google Custom Search. Reads 'searchterm_file' for next batch of queries, 
runs queries until CSLIMIT reached or response code 429 (daily query allowance exhausted under account policy)
and adds the responses to JSON 'queries_file'.

E.g. 

stfile="data/google/searchterms.txt"
qfile="data/google/cs_queries.json"

./scrape/custom_search.py $stfile $qfile
"""

import json
import requests
import os, sys 
from datetime import datetime, timedelta
from numpy import random

# google cs account
cx_key = os.environ['GOOGLE_CUSTOM_SEARCH_KEY']
cx_account = os.environ['GOOGLE_ACCOUNT'] 

# set wait time (days) before query term used again
RECENTDAYS = 14
CSLIMIT = 256

# read command line
try:
	searchterm_file = sys.argv[1];			del sys.argv[1]
	queries_file = sys.argv[1];			    del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "search_term_file json_file")
	sys.exit(1)

# get data
with open(queries_file, 'r') as qf:
    data = json.load(qf)
qf.close()
with open(searchterm_file, 'r') as sf:
    words = [w.strip() for w in sf.readlines()]
    # shuffle search terms to prevent bias to start of the array
    random.shuffle(words) 
sf.close()
print("Initial data has %d keys" % len(data))
print("Read %d search terms" % len(words))

# date routines
today = str( datetime.now().date() )

def is_recent(s, nr_days = RECENTDAYS):
    """
    s is a string of the for "yyyy-mm-dd"
    """
    date = datetime.strptime(s, "%Y-%m-%d")
    if date > datetime.now() - timedelta(days = nr_days):
        return True
    else:
        return False

def max_date(keys):
    if len(keys) == 1:
        return keys[0]
    else:
        dates = [datetime.strptime(k, "%Y-%m-%d") for k in keys]
        dates.sort()
        sorteddates = [datetime.strftime(d, "%Y-%m-%d") for d in dates]
        return sorteddates[-1]

# main loop
def get_responses():
    global data
    ctr = 0
    for w in words:
    
        if w in data:
            # if last update is recent then skip this query
            dates = list(data[w].keys())
            if len(dates) > 0:
                md = max_date(dates)
                if is_recent(md): 
                    continue
        else:
            data[w] = dict()
    
        # otherwise proceed
        search_term = w + "+(bird+species)"
        get_string = "https://www.googleapis.com/customsearch/v1?key=" + cx_key + \
        "&cx=" + cx_account + \
        "&sort=date&q=" + search_term
        response = requests.get(get_string)
        
        # check response code
        if response.status_code == 429 or ctr > CSLIMIT: 
            print(w, response.status_code)
            break
        if response.status_code != 200:
            continue
        
        # if OK
        ctr += 1   
        ret = response.json()    
        data[w][today] = ret
        if 'items' in ret.keys():
            print(w, response.status_code, ":", len(ret['items']))
        else:
            print(w, response.status_code)
    print(f"Processed {ctr} responses")


# write to disk
def write_to_disk():
    queries_file_dated = "data/webscan/google_cs_queries-%s.json" % today
    with open(queries_file_dated, 'w') as qf:
        json.dump(data, qf)
    qf.close()    
    os.system("cp %s %s" % (queries_file_dated, queries_file))
    print("Updated data has %d keys" % len(data))
    print("Written to %s with back-up %s" % (queries_file, queries_file_dated))

def main():
    get_responses()
    write_to_disk()
    return 0

if __name__ == '__main__':
	main()

# DONE