# BirdLife LitScan: web app & UI

The function of this service is to provide a web interface to the database published by the _process_ stage. This includes search capability, recommendations, data visualisations (as appropriate) and a portal for input of user feedback.

## How it currently works

The current version can be found at [http://blitscan.uksouth.azurecontainer.io:3838/](http://blitscan.uksouth.azurecontainer.io:3838/). It is implemented as an _R shiny_ app. The app is then bundled as a Docker container and deployed to Azure as a container instance.

A slimmed-down dataset – a CSV file containing just rows with good text and scored – is containerised with the app. This needs changing so that the deployed Docker container is independent of the daily data updates.

As to functionality: this is kept as lean as possible, and although by default recent articles are presented, the main function is search. 

All results are presented in descending score order, i.e. most relevant at the top. The traffic light indicators are based on score quantiles (green = top 25%, amber = middle 50%, red = bottom 25%). 


## Dashboard

The file _dashboard.Rmd_ is run as part of the process. It automatically generates the HTML file _dashboard.html_ in reports.

## Design thoughts

The main function currently wanting is interaction with the user, and especially: 

1. feedback on the traffic light (if the user thinks it should be higher or lower)
2. correcting the date (in some instances this is given incorrectly).

It could also include free-flow suggestions for improvement, journals or functionality to add etc.

The use of _R shiny_ is for legacy reasons and because the author doesn't do PHP or Node.js - but a re-write in one of these languages would be a good idea.


## TO-DO

- Migrate Azure App Service or Azure Webapp (rather than Container Instance), possibly as PHP or Node.js implementation.
- Decouple the data set, migrate to Azure SQL.
- Add a button to toggle between original and translated text for non-English content. 
- Replace the static date with a writable field that the user can manually overwrite.
- Replace the static traffic light with a dynamic one that can be 'rolled' to a different position.
- Build a pipeline of user input (date, score or free text) as a pub-sub service to the _process_ phase.
