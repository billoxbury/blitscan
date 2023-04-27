# BirdLife LitScan: web scraper

The function of this service is to crawl the web and to update the PostGres database with new documents – a document represented by a URL together with title, abstract (sometimes fuller text),  DOI, publication date, PDF link if known, and other metadata.

The end-to-end scraper service is called by the script _../run\_scan.sh_. It consists of two stages.

## Stage 1: collect URLs

The following R and Python scripts are run in sequence:

    ./custom_search_bing.py     # currently inactive due to T&C changes
    ./archive_indexes.R         # scans bioRxiv, J-Stage
    ./scan_openalex.R           # scans OpenAlex
    ./scan_oai_sources.R        # scans BioOne journals using OAI [if date = 0 mod 10]
    ./journal_indexes.R         # scans named journals explicitly [if date = 0 mod 10]
    ./scan_conbio.R             # scans blitshare/data/wiley/html for HTML files
                                                                  [if date = 0 mod 10]
    ./find_link_dois.py         # checks new results for DOI and adds these to _dois_ database table

Some comments:

The first of these scripts uses an Azure resource _blitscanCS_, which is a Bing Custom Search account. This specifies target domains e.g. _www.nature.com_, _journals.plos.org_, _www.orientalbirdclub.org_ etc (about 18 domains currently), and searches for species (scientific) names against these domains. 

However, Bing CS is now inactive because of [API use and display requirements](https://learn.microsoft.com/en-us/bing/search-apis/bing-web-search/use-display-requirements) which came into force in January 2023 preventing storage of search returns.

In the first three scripts (_bing_, _archive_ and _openalex_) each runs daily searches against a randomised subset of species scientific names. This subset is currently configured to 500 species, probabilistically weighted toward non-LC, non-EX IUCN categories.

The next two scripts (_oai_, _journal_) hoover up everything new they can find. They consult the database table _domains_ to look up X-path rules by which different domains store date/title/abstract/DOI as HTML metadata.

Some publishers prevent web scraping using services such as CloudFlare. If scraping is allowed, the field _minable_ is set to 1 in the table _domains_.

Wiley is one of the publishers that prohibits web scraping, and download of PDFs (for SCB journals) is allowed by special agreement with BirdLife International. However, locating these PDFs is a part manual process: HTML of recent contents pages is manually downloaded and stored in the directory _blitshare/data/wiley/html_. The script _scan\_conbio.R_ then reads these HTML files, finds all DOIs of new articles and adds these to the database.

The last script _find\_link\_dois.py_ checks all new DOIs that have been found and adds these to a separate database table _dois_ for later use.

## Stage 2: collect text





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
- Explore how to extend the process to subscription domains (as opposed to open access) – and role of CrossRef for this.
- Widen the set of text blocks that are extracted from each URL.
- Explore the optimisation problem (e.g. as a multi-armed bandit problem on the set of search terms).
