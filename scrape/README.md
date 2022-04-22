# BirdLife LitScan: web scraper

The function of this service is to crawl the web and publish a database of URLs together with text extracts plus publication date and other metadata.

## How it currently works

The current code runs four steps daily (some in two flavours, Google or Bing):

1. _custom_search_***.py_ Takes a list of web domains, plus a list of search terms (see _data_ directory), and runs a (Google or Bing) custom search against a random subset of the search terms. The top ten responses (consisting of URLs plus metadata) are stored in JSON format, indexed by the pair _(query date, search term)_.
2. _json_to_csv_***.py_ Scans the new URLs in the JSON file, filtering on some simple rules and adding the 'good' ones to a (CSV) database that will be used in steps 3,4.
3. _cs_get_html_text.R_ For each new URL in the database, requests the HTML and attempts to extract publication date, title, abstract and URL of any PDF. To do this, it reads a database _xpath_rules.csv_ from the data directory. This contains the HTML rules needed for each domain visited.
4. _cs_get_pdf_text.py_ Same as step 3, but this time following URL to PDF documents. 

Both steps 3,4 add the text/data found to the (CSV) database, and this is 'published' (i.e. stored in the _data_ directory for use by the _process_ service).

## Design thoughts

The current use of a local CSV file for the database is a hack and should move to the published database being stored in SQL or Mongo cloud storage.

The JSON file used in steps 1,2 should be thought of as private to the _scrape_ service. It is used to track usage of search terms (e.g. so they're not used too often) and for metrics.

Step 1 is amenable to optimisation: currently choices are made in both the choice of domains targeted, and the randomisation of the search terms. (I envisage for future work, application of machine learning to a feedback signal coming from the customer service _process_.)

Otherwise, note that this service makes no assessment of the URLs and text blocks it finds: its only job is to acquire these efficiently, given a specified set of domains and search terms, and customer feedback.

Note also that the current step 1 (cloud-based custom web search) is not the only way to acquire data. Another step supplementing step 1, for example, might be to directly scrape the contents pages of specified journals. (One for the TO-DO list.)

## TO-DO

In descending order of priority:

- Decouple the database (and JSON) into cloud storage.
- Widen the domain set until the coverage is felt to be realistically representative of the main sources used by BirdLife. (Should be informed by the most-cited sources by BirdLife in the recent past.)
- Add a scanning step for tables of contents of selected journals.
- Consolidate the acquisition rate from current domains. For example, some are giving large numbers of 503 server errors for reasons that aren't clear. 
[UPDATE: the issue here is some journals' use of Cloudflare. I've approached ConBio on this.]
- Explore how to extend the process to subscription domains (as opposed to open access).
- Related to the previous point, engage some of the journal publishers directly. Can they be persuaded to offer support as a 'global good'?
- Widen the set of text blocks that are extracted from each URL.
- Explore the optimisation problem (e.g. as a multi-armed bandit problem on the set of search terms).
