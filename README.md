# hu-ffman
Hu-Ffman - A basic Huffman encoder and decoder for the PC Engine

This is a Huffman encoding scheme for use on the PC Engine/Turbografx 16, 
but could be easily ported to other 6502-based consoles.
Included is a basic use-case that compresses two strings of text, 
but compression use-cases are not restricted to text.

Currently, it is limited to 64 unique bytes max, but it should be possible to expand that. 
Expanding it is beyond the scope of this project, 
which is supposed to be a simple showcase of how to implement huffman on the PC Engine.

---- HOW TO USE ----

Simply drag and drop the folder with your raw .BIN files into huffman.py

The python script will then output your data into the output folder.


This package includes a version of PCEAS from HuCC - https://github.com/jbrandwood/huc

The .pce file can be built by running the huffman_test.bat batch file
