#!/usr/bin/env python3
import sys

file = open(sys.argv[1], 'rb')
count = 160
for line in file:
	for char in line:
		if (char == 13) or (char == 10): continue
		sys.stdout.write(chr(count-char))
	count+=1
	if count > 285: count = 159
	print()
