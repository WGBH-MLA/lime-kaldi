#!/usr/bin/env python2
import sys, json, ftfy
inpath = sys.argv[1]
outpath = sys.argv[2]
print('Well hi there! I got input: ' + inpath + ' and output: ' + outpath)
word_list = []
with open(inpath) as infile:
  print('I plum got a dang file here! ' + inpath)
  output_dict = json.loads(infile.read(), encoding='utf-8')
  for d in output_dict['words']:
    word = d['word']
    word_list.append(ftfy.fix_text(word).lower())
    
with open(outpath, 'w') as outfile:
  transcript = ' '.join(word_list).encode('utf-8')
  outfile.write(transcript)
