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


## R shiny app

As to functionality: this is kept as lean as possible, and although by default recent articles are presented, the main function is search. 

All results are presented in descending score order, i.e. most relevant at the top. The traffic light indicators are based on score quantiles (green = top 25%, amber = middle 50%, red = bottom 25%). 



## Docker






## TO-DO

- Add a button to toggle between original and translated text for non-English content. 
- Replace the static date with a writable field that the user can manually overwrite.
- Replace the static traffic light with a dynamic one that can be 'rolled' to a different position.
- Build a pipeline of user input (date, score or free text) as a pub-sub service to the _process_ phase.
