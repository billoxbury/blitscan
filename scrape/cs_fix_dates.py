#!/usr/local/bin/python

"""
Take master CSV file and go through normalising the dates, and set BADLINK for old dates
"""

import sys
import pandas as pd
from dateutil.parser import parse
from datetime import datetime

DEFAULT_DAYSAGO = 1000
MAX_DAYSAGO = 1100

#  global constants
today = datetime.now().date()

# read command line
try:
	csvfile = sys.argv[1];			del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "csv_file")
	sys.exit(1)

# initialise
df = pd.read_csv(csvfile, index_col = None).fillna('')


def main():
    global df

    # repair dates - this includes parsing those extracted from HTML in 'cs_get_html_text.R'
    # as well as from PDF 
    for i in range(df.shape[0]):

        thisdate = df.at[i,'date']
        try:
            date = parse(thisdate, fuzzy=True).date()
            df.at[i, 'date'] = date.strftime("%Y-%m-%d")
            delta = today - date
            df.at[i, 'daysago'] = delta.days
            if delta.days > MAX_DAYSAGO:
                df.at[i, 'BADLINK'] = 1
        except:
            df.at[i, 'date'] = ""
            df.at[i, 'daysago'] = DEFAULT_DAYSAGO
            continue

    # write to disk
    df.to_csv(csvfile, index = False)
    print(f'{df.shape[0]} records written to {csvfile}')
    return 0

if __name__ == '__main__':
	main()

# DONE