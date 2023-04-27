# BirdLife LitScan: text processor

The function of this service is to take blocks of text and to perform various analytics, updating the main database table with the results.

The end-to-end processing service is called by the script _../run\_proc.sh_. This runs the following Python scripts in sequence:

    ./fix_dates.py                  # check all dates are normalised to yyyy-mm-dd 
    ./detect_language.py            # detect language where not already found from metadata
    ./find_species.py               # spaCy entity extraction used to find all common and scientific names
    ./translate_to_english.py       # Azure Translator used for all non-English text containing species
    ./score_for_topic.py            # score for conservation relevance

A few comments:

Translation to English uses the Azure Translator resource _blitscanTRANS_. To minimise the cost of this service, language detection and species extraction precede the translation call. Both use _spaCy_.

For non-English articles, translations are added to the database in the _title\_translation_ and _abstract\_translation_ fields. Scoring for relevance then runs on English text for all items. 

It is desirable to extend non-English coverage of LitScan in the future. The benefit of this has been discussed briefly in [this blog](https://medium.com/@oxburybill/language-barriers-in-global-conservation-4bafd3d598d3).

The main innovation of LitScan is its relevance scoring. This uses a bag-of-words model trained on 11,000 BirdLife species assessments. A technical wrote-up of the method is in progress. The model training code is in the directory _./models_, and the model itself is stored as a JSON file: 

    blitshare/bli_model_bow_11107.json





