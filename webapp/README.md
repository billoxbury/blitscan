# BirdLife LitScan: web app & dashboard

The function of this service is to provide a web interface to the database maintained by the _scrape_ and _process_ stages. This should include search capability, recommendations, data visualisations (as appropriate) and a portal for user input (PDF uploads, feedback on relevance etc).

The web app is written in R, uploaded to Azure as a Docker container and deployed as an Azure Web App resource _blitscanapp_. It is updated by the script _../run\_app\_update.sh_. This performs the following steps:

    - run R::rmarkdown on dashboard.Rmd to create dashboard.html
    - copy dashboard.html to ./www and to blitshare/reports
    - build docker image
    - push docker image to Azure
    - delete local docker image
    - restart blitscanapp on Azure

(Note: currently these steps are also preceded by _update\_DOI\_data.R_ and _get\_wiley\_pdf.py_. Logically these belong in the _scrape_ service, and are only here as a temporary hack because of problems running them in the Azure VM.)

Here is some more detail.

## Dashboard

_./dashboard.Rmd_ is an R markdown script that computes various summaries on the current state of the database. It has two outputs: _dashboard.html_ which is published with the web app, and a row with today's date added to the table _progress_ in the database:

                Table "public.progress"
      Column   |  Type   | Collation | Nullable | Default 
    ------------+---------+-----------+----------+---------
    date       | text    |           | not null | 
    docs       | integer |           |          | 
    species    | integer |           |          | 
    titles     | integer |           |          | 
    publishers | integer |           |          | 
    LC         | integer |           |          | 
    NT         | integer |           |          | 
    VU         | integer |           |          | 
    EN         | integer |           |          | 
    CR         | integer |           |          | 
    EX         | integer |           |          | 
    DD         | integer |           |          | 
    PE         | integer |           |          | 
    EW         | integer |           |          | 
    pdf        | integer |           |          | 
    Indexes:
        "progress_pk" PRIMARY KEY, btree (date)

The HTML file overwrites the current version in the subdirectory _./www_ (ignored by git), but is also stored in _blitshare/reports_ with today's date appended to the filename (so without overwriting). 

## R shiny app

The web app is implemented in [R shiny](https://shiny.rstudio.com/). It uses four resources in this directory:

    ./setup.R       # preamble, database access, function definitions
    ./ui.R          # UI construction
    ./server.R      # server functions
    ./www/          # folder for docs & images needed by the app 

In particular, _dashboard.html_ is made available to the app by inclusion in _www/_.

An important variable set in _setup.R_ is _LOCAL_. This is set to _FALSE_ for Azure deployment, but needs to be set to _TRUE_ for debugging on a local host.

## Docker

This should all be self-explanatory, but there are a few comments to make.

The Docker container needs access to the Azure file share _blitshare_, in order to read PostGres credentials for database access. So _blitshare_ is mounted at runtime – either locally with -v option, or (as in the web app) at time of setting up the container instance in Azure.

In terms of Azure resources: the Docker image is uploaded to the Container Registry _blitscanappcontainers_ as the 'repository' _blitscanpg_. This repository is called by the web app _blitscanapp_, with the _blitshare_ mount configured under 'path mappings'.

For debugging the app at development time, the process is: first debug in R running locally (with the _LOCAL_ variable set to _TRUE_); once working in R, degug the Docker container running locally (there are command lines for this commented out in the script _run\_app\_update.sh_); finally, if there are problems running the trusted container from the web app, one should consult the Azure logs for _blitscanapp_.

Finally, a remark about the folder _www/_. This is not visible in GitHub, but has contents:

    www/dashboard.html
    www/logo/
    www/score/
    www/upload/

The first has been discussed; the second and third contain images used by the app (e.g. traffic lights). The last _www/upload/_ contains all PDFs uploaded via the file upload widget in the app. This is inefficient as the the whole set of PDFs has to be uploaded with the Docker image at every update. _It needs to be replaced by a mechanism by which the app accesses a static PDF repository in blitshare._

## Azure architecture

The Azure resources in use for basic deployment of the web app have been discussed: 

    blitscanapp             # Web App
    blitscanASP             # App Service Plan (where Azure manages the app)
    blitscanappcontainers   # container registry hosting Docker image
    blitstore               # storage account containing file share
    blitscan-pg             # PostGres database

With these resources the running app can be accessed at a URL listed in the web app's control pane. However, this is not sufficient for secure deployment to the BirdLife domain running behind the BirdLife firewall. For this the following networking resources are also needed:

    BlitAG                  # Application Gateway
    blitIP                  # Public IP address assigned to the gateway
    blitVN                  # Virtual Network with subnets hosting the web app and the app gateway

The BirdLife firewall is then linked to the application gateway via the public IP address.

