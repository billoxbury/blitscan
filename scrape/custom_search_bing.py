#!/usr/local/bin/python

"""
Performs Bing Custom Search. Reads 'searchterm_file' for next batch of queries, 
runs queries until CSLIMIT reached or response code 429 (daily query allowance exhausted under account policy)
and adds the responses to JSON 'queries_file'.

E.g. 

stfile="data/webscan/searchterms.txt"
qfile="data/webscan/bing_cs_queries.json"

./scrape/bing_custom_search.py $stfile $qfile
"""

import json
import requests
import os, sys 
import time
from datetime import datetime, timedelta
from numpy import random

# Bing CS account 
subscriptionKey = os.environ['BING_CUSTOM_SEARCH_SUBSCRIPTION_KEY']
endpoint = os.environ['BING_CUSTOM_SEARCH_ENDPOINT']
customConfigId = os.environ['BING_CUSTOM_CONFIG'] 

# set wait time (days) before query term used again
RECENTDAYS = 14
CSLIMIT = 1000
WAITTIME = 0.01  # time between calls: 1 second on F0 free tier, 0.01 second on S1 standard tier

# read command line
try:
	searchterm_file = sys.argv[1];			del sys.argv[1]
	queries_file = sys.argv[1];			    del sys.argv[1]	
except:
	print("Usage:", sys.argv[0], "search_term_file json_file")
	sys.exit(1)

# get data
try:
    with open(queries_file, 'r') as qf:
        data = json.load(qf)
    qf.close()
except:
    data = dict()
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
    ctr = CSLIMIT
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
            data[w][today] = items
            print(f'{ctr}: {len(items)} {w}')
        except:
            print(f'Response {response.status_code}: 0 {w}')
    print(f"Processed {CSLIMIT} responses")

# write to disk
def write_to_disk():
    with open(queries_file, 'w') as qf:
        json.dump(data, qf)
    qf.close()    
    print("Updated data has %d keys" % len(data))

def main():
    get_responses()
    write_to_disk()
    return 0

if __name__ == '__main__':
	main()

# DONE