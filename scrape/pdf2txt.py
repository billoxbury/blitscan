"""
Package of routines for PDF text extraction
"""

import spacy
import re
import fitz
from spacy.matcher import Matcher                                                                                                
from spacypdfreader import pdf_reader
                                                              

##############################################################
# parameters

ABSTRACT_COUNT = 15

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
# general string functions

def _is_good_chunk(txt, patt = filter_patt):
    """
    Private
    txt is string
    """
    condition = bool( len(txt.split()) <= 5 ) or bool(patt.search(txt))
    return (not condition)

def guess_abstract(text_list):
    """
    Public
    text_list as output by get_text()
    """
    return ' '.join(text_list[:ABSTRACT_COUNT])

def guess_title(text_list):
    """
    Public
    text_list as output by get_text()
    """
    return '\n'.join([str(s) for s in text_list[:2]])


##############################################################
# fitz-dependent functions

def parse_creation_date(filepath):
    """
    Public
    """
    pdf_doc = fitz.open(filepath)
    date = pdf_doc.metadata['creationDate']
    return f'{date[2:6]}-{date[6:8]}-{date[8:10]}'

def get_title(filepath):
    """
    Public
    """
    pdf_doc = fitz.open(filepath)
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
    Public
    ... or use different model
    """
    nlp = spacy.load(model) 
    nlp.add_pipe('sentencizer')
    return nlp

def _make_sentence_list(nlp_doc):
    """
    Private
    nlp_doc as output by nlp()
    Ouputs list of strings
    """
    sent1 = list(nlp_doc.sents)
    sent2 = [str(s) for s in sent1]
    groups = [s.split('\n\n') for s in sent2]
    return [s.replace('\n', ' ') for s in sum(groups, []) if _is_good_chunk(s)]

def get_text(nlp, filepath):
    """
    Public
    nlp as output by make_nlp_pipeline()
    """
    doc = pdf_reader(filepath, nlp)
    text = _make_sentence_list(doc)
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