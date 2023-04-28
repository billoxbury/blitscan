# BirdLife LitScan

This repository contains code for a Birdlife International project [LitScan](https://litscan.birdlife.org) on search/information discovery from the scientific literature. 

The aims of the project are to compile in one place links to web resources relevant to the work of BirdLife in making assessments of species' IUCN red-list status.

The LitScan codebase divides into three component services:

1. Scan the web for content, which gets stored in a PostGres database.
2. Process text in the database: translate to English, score for relevance, locate species mentions.
3. Web app: UI for access to database results, plus dashboard.

Functions under 1,2,3 are treated as independent micro-services. In the current repo, they are represented by code in the directories _scrape_, _process_, _webapp_. Each of these directories has its own _README_ file that describes the service in more detail.

The services 1,2,3 are run as a single end-to-end process by the script _run\_all.sh_. This calls a script for each service, more details of which can be found in the respective _README_ files.

We'll say a word in this _README_ about the database and about the Azure deployment.

## PostGres database

All three services talk to a PG database. It contains various tables, of which two should be mentioned here.

_links_ is the main table of documents, indexed by field _link_ which is a URL of the document. Its strucutre is:

                           Table "public.links"
           Column        |       Type       | Collation | Nullable | Default 
    ----------------------+------------------+-----------+----------+---------
    date                 | text             |           |          | 
    link                 | text             |           | not null | 
    link_name            | text             |           |          | 
    snippet              | text             |           |          | 
    language             | text             |           |          | 
    title                | text             |           |          | 
    abstract             | text             |           |          | 
    pdf_link             | text             |           |          | 
    domain               | text             |           |          | 
    search_term          | text             |           |          | 
    query_date           | text             |           |          | 
    badlink              | integer          |           |          | 
    donepdf              | integer          |           |          | 
    gottext              | integer          |           |          | 
    gotscore             | integer          |           |          | 
    gotspecies           | integer          |           |          | 
    score                | double precision |           |          | 
    species              | text             |           |          | 
    doi                  | text             |           |          | 
    title_translation    | text             |           |          | 
    abstract_translation | text             |           |          | 
    gottranslation       | integer          |           |          | 
    donecrossref         | integer          |           |          | 
    pdftext              | text             |           |          | 
    pdftext_translation  | text             |           |          | 
    datecheck            | integer          |           |          | 
    Indexes:
        "links_pkey" PRIMARY KEY, btree (link)

The integer fields 'badlink' etc are used as boolean flags for processing control.

_species_ contains BirdLife International's species information. Its structure is:

                Table "public.species"
      Column   |  Type   | Collation | Nullable | Default 
    ------------+---------+-----------+----------+---------
    link       | text    |           |          | 
    name_com   | text    |           |          | 
    name_sci   | text    |           |          | 
    SISRecID   | integer |           |          | 
    date       | text    |           |          | 
    text_main  | text    |           |          | 
    text_short | text    |           |          | 
    status     | text    |           |          | 
    recog      | text    |           |          | 
    syn        | text    |           |          | 
    alt        | text    |           |          | 

The file _pg\_views.sh_ in this directory contains informal notes and some examples of views into the database.

## Azure deployment

Deployment of the whole system is in Microsoft Azure. It lives under a single subscription and is subdivided into three resource groups _scrapeRG_, _procRG_ and _webappRG_. 

Resources common to all three components, such as the database _blitscan-pg_, are hosted under _webappRG_. This also includes a storage account _blitstore_, which contains a single file share _blitshare_. 

_blitshare_ has a directory structure:

    /costing        - contains some cost estimate reports
    /data           - mainly temporary storage for PDF processing; some legacy data sets
    /pg             - protected PostGres credentials for access to the database
    /reports        - location for reports, including a subdirectory of 'scraper' dashboard files

Code from _scrape_ and _process_ (LitScan services 1,2) are run in an Ubuntu virtual machine _blitscanVM_. The file _azure\_vm.sh_ in this directory contains code for installing the necessary software stack in this VM.

The webapp (LitScan stage 3) is deployed as an Azure web app _blitscanapp_, wich runs a Docker container held in the container registry _blitscanappcontainers_. More details can be found in the _scrape_ _README_ file.