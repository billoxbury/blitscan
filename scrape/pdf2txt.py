"""
Package of routines for PDF text extraction
"""

import spacy
import re
from spacy.matcher import Matcher                                                                                                                                                                                         

##############################################################
# parameters

ABSTRACT_COUNT = 10

# regex to filter out stuff we're not interested in
# used in is_good_chunk() below
filter_string = "^Copyright:|" + \
    "^Editor:|" + \
    "^Accepted:|" + \
    "<image|" + \
    "¤ Current address:|" + \
    "^PLOS ONE|" + \
    "^Scientific Reports \||" \
    "^Data Availability Statement:|" + \
    "^Funding:|" + \
    "^Citation:|" + \
    "^Received:|" + \
    "^How to cite this article|" + \
    "^([A-Z] ){6}|" + \
    "^Competing interests:|" + \
    "^Fig[.]? \d+|" + \
    "^Table \d+|" + \
    "^\d+\.\n|" + \
    "^Conceptualization:|" + \
    "^Data curation:|" + \
    "^Formal analysis:|" + \
    "^Funding acquisition:|" + \
    "^Writing – original draft:|" + \
    "published by Wiley Periodicals LLC|" + \
    "^Writing – review & editing:|" + \
    ".+http(s?):.+|" + \
    ".+\|.+|" + \
    "^©|" + \
    "^Page \d+"
filter_patt = re.compile(filter_string)


##############################################################
# fitz-dependent functions

def parse_creation_date(pdf_doc):
    """
    pdf_doc as output by fitz.open(_filename_)
    """
    date = pdf_doc.metadata['creationDate']
    return f'{date[2:6]}-{date[6:8]}-{date[8:10]}'

def get_title(pdf_doc):
    """
    pdf_doc as output by fitz.open(_filename_)
    """
    formal_title = ""
    guess_title = ""
    if 'title' in pdf_doc.metadata:
        formal_title = pdf_doc.metadata['title']
    if len(pdf_doc.get_toc()) > 0:
        guess_title = pdf_doc.get_toc()[0][1]
    if formal_title.lower() == guess_title.lower():
        title = formal_title
    elif len(formal_title) > len(guess_title):
        title = formal_title
    else:
        title = guess_title
    return title


##############################################################
# spacy-dependent functions

def make_nlp_pipeline(model = 'en_core_web_md'):
    """
    ... or use different model
    """
    nlp = spacy.load(model) 
    nlp.add_pipe('sentencizer')
    return nlp

def make_sentence_list(nlp_doc):
    """
    nlp_doc as output by nlp()
    """
    sentences = list(nlp_doc.sents)
    return sentences

def verbs(nlp, sent):
    """
    nlp as output by make_nlp_pipeline()
    sent = sentence list
    """
    pattern=[
        {'POS': 'VERB', 'OP': '?'},
        {'POS': 'ADV', 'OP': '*'},
        {'POS': 'VERB', 'OP': '+'}
    ]
    # instantiate a Matcher instance
    matcher = Matcher(nlp.vocab) 
    # add pattern to matcher
    matcher.add('verb-phrases', [pattern])
    d = nlp(sent.text)
    # call the matcher to find matches 
    matches = matcher(d)
    spans = [d[start:end] for _, start, end in matches] 
    return spans

def clean_sentences(nlp, sents):
    sentences = [str(s).replace('- ','') for s in sents if len(verbs(nlp, s)) > 0 and
                    len(s) > 3]
    return sentences

def get_text(nlp, pdf_doc):
    """
    nlp as output by make_nlp_pipeline()
    pdf_doc as output by fitz.open(_filename_)
    """
    pages = [pdf_doc[i].get_text('blocks') for i in range(pdf_doc.page_count)]
    all_blocks = sum(pages, [])
    raw_text = ''.join([b[4] for b in all_blocks]).replace('\n', ' ')
    doc = nlp(raw_text)
    sents = clean_sentences(nlp, make_sentence_list(doc))
    text = [s for s in sents if is_good_chunk(s)]
    # so far so good - now locate start of the abstract
    idx = -1
    for i in range(len(text)):
        x = text[i]
        if bool(re.search('abstract', x.lower())):
            y = x.lower().split('abstract')
            idx = i
            init = y[1].strip(':|\.| ')
            break
    # if successful, start from here
    if idx >= 0:
        text = [init.capitalize()] + text[(idx+1):]
    return text

##############################################################
# general string functions

def is_good_chunk(txt, patt = filter_patt):
    """
    txt is string
    """
    condition = bool( len(txt.split()) <= 5 ) or bool(patt.search(txt))
    return (not condition)

def get_abstract(text_list):
    """
    text_list as output by get_text()
    """
    return ' '.join(text_list[:ABSTRACT_COUNT])
