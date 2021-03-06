# BirdLife LitScan: web scraper

The function of this service is to crawl the web and publish a database of URLs together with text extracts plus publication date and other metadata.

## How it currently works

The current code runs the following steps daily (some in two flavours, Google or Bing):

1. _custom_search_***.py_ Takes a list of web domains, plus a list of search terms (see _data_ directory), and runs a (Google or Bing) custom search against a random subset of the search terms. The top ten responses (consisting of URLs plus metadata) are stored in JSON format, indexed by the pair _(query date, search term)_.
2. _json_to_csv_***.py_ Scans the new URLs in the JSON file, filtering on some simple rules and adding the 'good' ones to a (CSV) database that will be used in steps 3,4.
3. _journal_indexes_to_csv.R_ adds more URLs to the CSV database by targeted search of journal listings.
4. _cs_get_html_text.R_ For each new URL in the database, requests the HTML and attempts to extract publication date, title, abstract and URL of any PDF. To do this, it reads a database _xpath_rules.csv_ from the data directory. This contains the HTML rules needed for each domain visited.
5. _cs_get_pdf_text.py_ Same as step 3, but this time following URL to PDF documents. 

The last two steps both add the text/data found to the (CSV) database, and this is 'published' (i.e. stored in the _data_ directory for use by the _process_ service).

Step 3 now also includes a scan of content archives (bioRxiv, J-Stage) which works differently from the journal scans. The journal scans simply read tables of content for recent issues. The archive scans loop over randomised queries on _scientific genus names_. Moreover, they restrict to genera that are not _LC_ or _EX_. This information is read from the data file _searchterms-restricted_. The construction of _searchterms-restricted_, which uses information scraped from BirdLife DataZone, is contained in the Jupyter notebook _make-search-terms.ipynb_.

## Metrication

The file _scraper_dashboard.Rmd_ is now run as part of the process. This automatically generates the HTML file  _scraper_dashboard.html_ in _reports_. (NOTE: annoyingly GitHub won't render the HTML file, but it's easily downloaded and viewed on your desktop.)

## Design thoughts

We should consider targetting non-English as well as English language results, but depending on the query term/species. We could use BirdLife data zone geo information for this.

The current use of a local CSV file for the database is a hack and should move to the published database being stored in SQL or Mongo cloud storage.

The JSON file used in steps 1,2 should be thought of as private to the _scrape_ service. It is used to track usage of search terms (e.g. so they're not used too often) and for metrics.

Step 1 is amenable to optimisation: currently choices are made in both the choice of domains targeted, and the randomisation of the search terms. (I envisage for future work, application of machine learning to a feedback signal coming from the customer service _process_.)

Otherwise, note that this service makes no assessment of the URLs and text blocks it finds: its only job is to acquire these efficiently, given a specified set of domains and search terms, and customer feedback.

Note also that the current step 1 (cloud-based custom web search) is not the only way to acquire data. Another step supplementing step 1, for example, might be to directly scrape the contents pages of specified journals. (Started.)

## TO-DO

- Get ConBio working once Wiley token is granted.
- Add scanners for _scielo_ and for ConBio (when available).
- Get Custom Search working on Birdlife Azure once the cost mgt issue is sorted out.
- Explore use of CrossRef as a fourth crawler method (after Bing CS, journal scans, archive queries)
- Explore how to extend the process to subscription domains (as opposed to open access) ??? and role of CrossRef for this.
- Widen the set of text blocks that are extracted from each URL.
- Explore the optimisation problem (e.g. as a multi-armed bandit problem on the set of search terms).
