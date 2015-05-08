#!/usr/bin/env lua

local DBI = require('DBI')

local dbh = assert(DBI.Connect("MySQL", "jm2l", "", "", ""))

local sth = assert(dbh:prepare('select * from PhySalles'))

sth:execute()

local columns = sth:columns()

print([[
<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<title>[JM2L] Salles physiques Polytech</title>
		<style>body { font-size: 0.9em }</style>
	</head>
	<body>
]])

for row in sth:rows(true) do
	print("<h3>" .. row.uid .. " - " .. row.name .. " - " .. row.nb_places .. "</h3>")
	print(row.description)
end

print([[
	</body>
</html>
]])
