#!/usr/local/bin/python

"""
Take a PDF file 'filename.pdf' and output a simple html file 'filename.pdf.html' of the form
<body>
<p>sentence 1</p>
<p>sentence 2</p>
<p>sentence 3</p>
...
</body>

E.g. 

infile="data/pdf/tmp/somename.pdf"

./process/pdf_get_text.py $infile

"""

import sys
from pathlib import Path
import fitz
import spacy
from spacy.matcher import Matcher                                                                                                                                                                                         
#from spacy.matcher import PhraseMatcher
#from spacy.tokens import Span
#from spacy.lang.en import English
#from spacy.pipeline import EntityRuler

ABSTRACT_SENTENCE_THRESHOLD = 2
PDF_PATH = "data/pdf"

# read command line
try:
	filename = sys.argv[1];			del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "filename")
	sys.exit(1)

# set download path
download_path = f'{PDF_PATH}/{filename}'

# function definitions
def get_title(pdf_doc):
    if 'title' in pdf_doc.metadata:
        return pdf_doc.metadata['title']
    elif len(pdf_doc.get_toc()) > 0:
        return pdf_doc.get_toc()[0][1]
    else:
        return None

def make_nlp_pipeline():
    nlp = spacy.load('en_core_web_md') 
    nlp.add_pipe('sentencizer')
    return nlp

def make_sentence_list(nlp_doc):
    sentences = list(nlp_doc.sents)
    return sentences

def verbs(sent, nlp):
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

def clean_sentences(sents, nlp):
    sentences = [s for s in sents if len(verbs(s, nlp)) > 0 and
                    len(s) > 3]
    return sentences

def get_abstract(pdf_doc, nlp):
    pages = [pdf_doc[i].get_text('blocks') for i in range(pdf_doc.page_count)]
    all_blocks = sum(pages, [])
    for b in all_blocks:
        doc = nlp(b[4])
        sents = clean_sentences(
            make_sentence_list(doc),
            nlp
            )
        if len(sents) > ABSTRACT_SENTENCE_THRESHOLD:
            abstract = b[4]
            break
    return abstract

def main():
    infile = Path(download_path)
    pdf_doc = fitz.open(infile)
    nlp = make_nlp_pipeline()
    title = get_title(pdf_doc)
    abstract = get_abstract(pdf_doc, nlp)
    print( f'Title:\n{title}' )
    print( f'Abstract:\n{abstract}' )
    return 0

if __name__ == '__main__':
	main()

# DONE