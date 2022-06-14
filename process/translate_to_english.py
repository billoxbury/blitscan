#!/usr/local/bin/python

"""
Take a CSV file with fields 'title', 'abstract', 'title_translation', 'abstract_translation'.
When language field is not 'en' (and GOTTRANSLATION is not yet set), 
makes Azure Translator query and populates the translation fields.

"""

import pandas as pd
import os, sys
import requests, uuid

# read command line
try:
	datafile = sys.argv[1];			 	del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "csvfile")
	sys.exit(1)

# read data frame with text fields
df = pd.read_csv(datafile, header=0).fillna('')

# Add subscription key endpoint, parameters etc
subscription_key = os.environ['AZURE_TRANSLATION_SUBSCRIPTION_KEY']
endpoint = os.environ['AZURE_TRANSLATION_ENDPOINT']
location = os.environ['AZURE_TRANSLATION_LOCATION']
constructed_url = endpoint + '/translate'
params = {
    'api-version': '3.0',
    'to': 'en'
}
headers = {
    'Ocp-Apim-Subscription-Key': subscription_key,
    'Ocp-Apim-Subscription-Region': location,
    'Content-type': 'application/json',
    'X-ClientTraceId': str(uuid.uuid4())
}

def main():
	global df
	ctr = 0
	# make translation requests
	print("Computing item scores")
	for i in range(df.shape[0]): 
		if df.at[i, 'GOTTEXT'] == 0: continue
		if df.at[i, 'language'] == 'en': continue
		if df.at[i, 'GOTTRANSLATION'] == 1: continue
		body = [{'text': df.at[i, "title"]},
				{'text': df.at[i, "abstract"]}]
		try:
			request = requests.post(constructed_url, params=params, headers=headers, json=body)
			response = request.json()
			df.at[i, 'title_translation'] = response[0]["translations"][0]["text"]
			df.at[i, 'abstract_translation'] = response[1]["translations"][0]["text"]
			df.at[i, 'GOTTRANSLATION'] = 1
			ctr += 1
		except:
			continue
    # write to disk
	df.to_csv(datafile, index = False)
	print(f"Scored {ctr} rows and written to {datafile}")        

##########################################################

if __name__ == '__main__':
	main()
