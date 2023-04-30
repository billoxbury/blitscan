# BirdLife LitScan: scanner

The function of this service is to crawl the web and to update the PostGres database with new documents. A document is represented by a URL together with title, abstract (sometimes fuller text),  DOI, publication date, PDF link if known, and other metadata.

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

However, Bing CS is now inactive because of [API use and display requirements](https://learn.microsoft.com/en-us/bing/search-apis/bing-web-search/use-display-requirements) which came into force in January 2023 prohibiting storage of search returns.

The first three scripts (_bing_, _archive_ and _openalex_) each run daily searches against a randomised subset of species scientific names. This subset is currently configured to 500 species, probabilistically weighted toward non-LC, non-EX IUCN categories.

The next two scripts (_oai_, _journal_) hoover up everything new they can find. They consult the database table _domains_ to look up X-path rules by which different domains store date/title/abstract/DOI as HTML metadata.

Some publishers prevent web scraping using services such as CloudFlare. If scraping is allowed, the field _minable_ is set to 1 in the table _domains_.

Wiley is one of the publishers that prohibits web scraping, and download of PDFs (for SCB journals) is allowed by special agreement with BirdLife International. However, locating these PDFs is a part manual process: HTML of recent contents pages is manually downloaded and stored in the directory _blitshare/data/wiley/html_. The script _scan\_conbio.R_ then reads these HTML files, finds all DOIs of new articles and adds these to the database.

The last script _find\_link\_dois.py_ checks all new DOIs that have been found and adds these to a separate database table _dois_ for later use.

## Stage 2: collect text

The following R and Python scripts are run in sequence:

    get_html_text.R             # use X-path rules to extract title/abstract from new URLs
    update_DOI_data.R           # use CrossRef to get publication details against new DOIs
    get_wiley_pdf.py            # check DOI data for new Wiley articles and download PDFs
    read_pdf_uploads.py         # get text from manually uploaded PDFs (by BirdLife International users)
    read_wiley_pdf.py           # get text from Wiley PDFs
    get_pdf_text.py             # for minable domains, download PDF, read text, delete PDF
    remove_duplicates.sh        # dedupe main table for URL; dedupe DOI table

At the end of this process, the database has been update with new document text. This text is title plus abstract only if, as in the majority of cases, these are available from metadata. Where text is not available from metadata, we download and extract text from PDF if we have a link. Or we extract text from PDF is where we have no choice (e.g. Wiley, manually uploaded PDFs).

Text extraction from PDF is imperfect and uses routines in _./pdf2txt.py_ (which in turn calls libraries _PyMuPDF_ and _spaCy_). 

(Comment: the position of _update\_DOI\_data.R_ in the above sequence is logical, though in practice it currently runs elsewhere because of a bug that needs fixing which prevents the library _rcrossref_ running on the Ubuntu VM.)

## Tasks (scanner)

- Review Bing storage with Microsoft
- Review Google Scholar API and usage
- Add new sources in response to user requests
- Monitor per-domain format and x-paths [ongoing]
- Expand non-English coverage (e.g. in partnership with Queensland team)
- Refine and improve the PDF processing
