# BirdLife LitScan

This repository contains code for a Birdlife International project on search/information discovery from the scientific literature. 

The aims of the project are to compile in one place links to web resources (currently that means open access journal articles, but we hope to grow the scope) relevant to the work of BirdLife in making assessments of species' red-list status.

The LitScan process logically has three components:

1. Scrape the web for titles/abstracts and other content.
2. Apply text analysis to score for relevance, locate species mentions etc.
3. Present recommender as web app UI.

In a cloud deployment, 1,2,3 should be treated as autonomous micro-services (or teams of micro-services). In the current repo, they are represented by code in the directories _scrape_, _process_, _webapp_. Each of these directories has its own _README_ file.

In the current alpha-version 1,2,3 are run as a single end-to-end process by the script _run.sh_.

More details on how everything works are described in the _reports_ directory (currently a March write-up which will be updated).