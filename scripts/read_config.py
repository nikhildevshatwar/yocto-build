#!/usr/bin/python3
# Author: Nikhil Devshatwar
# This simple script is used for reading values from INI configuration file

import configparser;
import sys;

def usage():
	sys.stderr.write("Usage: read_config.py FILENAME SECTION PARAM\n")

if (len(sys.argv) != 4):
	usage()
	sys.exit(1)
else:
	configfile = sys.argv[1]
	section = sys.argv[2]
	param = sys.argv[3]

try:
	config = configparser.ConfigParser()
	config.read(configfile)
	print (config.get(section, param))
except:
	print ("")
