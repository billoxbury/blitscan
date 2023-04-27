# BirdLife LitScan: text processor

The function of this service is to take blocks of text and to perform various analytics, updating the main database table with the results.

The following Python scripts are run in sequence:

    ./fix_dates.py                  # check all dates are normalised to yyyy-mm-dd 
    ./detect_language.py            # detect language where not already found from metadata
    ./find_species.py               # spaCy entity extraction used to find all common and scientific names
    ./translate_to_english.py       # Azure Translator used for all non-English text containing species
    ./score_for_topic.py            # score for conservation relevance





