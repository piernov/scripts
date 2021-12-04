#!/usr/bin/env python3
import sys

file = open(sys.argv[1], 'r')
f2 = open(sys.argv[2], 'wb')
count = 160
for line in file:
	for char in line:
#		print(char, end='')
		if (char == 13) or (char == 10): continue
#		sys.stdout.write(chr(char-count))
		print(count-ord(char), end = '')
		print(' ', end = '')
		f2.write((count-ord(char)).to_bytes(1, byteorder='little'))
	count+=1
	if count > 285: count = 159
	print()
	f2.write(bytearray('\n', 'utf-8'))
#	f2.write(bytearray('\n'))
#	print()
