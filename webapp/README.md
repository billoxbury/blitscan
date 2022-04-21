# BirdLife LitScan: web app & UI

The function of this service is to provide a web interface to the database published by the _process_ stage. This includes search capability, recommendations, data visualisations (as appropriate) and a portal for input of user feedback.

## How it currently works

The current version can be found at [http://20.108.194.71:3838/](http://20.108.194.71:3838/). You'll notice two things (at least!). First, that it's not secure (http instead of https) – that's top of the to-do list to fix. Second, that the port number is 3838, because it's implemented as an _R shiny_ app. The app is then bundled as a Docker container and deployed to Azure as a container instance.

A slimmed-down dataset – a CSV file containing just rows with good text and scored – is containerised with the app. This needs changing so that the deployed Docker container is independent of the daily data updates.

As to functionality: this is kept as lean as possible, and although by default recent articles are presented, the main function is search. 

All results are presented in descending score order, i.e. most relevant at the top. The traffic light indicators are based on score quantiles (green = top 25%, amber = middle 50%, red = bottom 25%). 


## Design thoughts

The main function currently wanting is interaction with the user, and especially: 

1. feedback on the traffic light (if the user thinks it should be higher or lower)
2. correcting the date (in some instances this is given incorrectly).

It could also include free-flow suggestions for improvement, journals or functionality to add etc.

The use of _R shiny_ is for legacy reasons and because the author doesn't do PHP or Node.js - but a re-write in one of these languages would be a good idea.


## TO-DO

- Secure the app behind _https_. (In the current _R shiny_ implementation this is possible only with a corporate _R_ subscription. A better approach might be a port to another language such as PHP or Node.js) 
- Decouple the data set from the web app container.
- Replace the static date with a writable field that the user can manually overwrite.
- Replace the static traffic light with a dynamic one that can be 'rolled' to a different position.
- Build a pipeline of user input (date, score or free text) as a pub-sub service to the _process_ phase.
