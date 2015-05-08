#!/usr/bin/env lua

package.cpath=package.cpath .. ";/usr/lib/lua/?.so"

require("gv")


local piles = { 1, 3, 5, 7}
local coups  = { 1, 2, 3 }
local nolinks = true


local childs = {}

local function add_node(piles, coups, parent, p)

	local retcolor = p
	p = p == "B" and "N" or "B"

	if #piles <1 or #coups <1 then
		return
	end

	local tree = {}
	local tmpchilds = {}

	for k,v in ipairs(piles) do
		for i,j in ipairs(coups) do

			local tmppiles = {}

			for k,v in ipairs(piles) do
				tmppiles[k] = v
			end


			if tmppiles[k] >= j then 

				tmppiles[k] = v - j

				table.sort(tmppiles)

				local name = table.concat(tmppiles, " ")

				if not tmpchilds[name] then
					tmpchilds[name] = true

					local color
					local tbl
					if not childs[name] then
						tbl, color = add_node(tmppiles, coups, child, p)
						table.insert(tree, {name = tmppiles, content = tbl, color = color, p = p} )

						childs[name] = { name = c, content = tbl, color = color, p = p }
					else
						tbl = childs[name]
						local ccolor = childs[name].color
						local tp = childs[name].p

						if p == tp then
							color = ccolor
						else
							color = ccolor == "B" and "N" or "B"
						end

						table.insert(tree, {name = tmppiles, content = tbl, color = color, p = p} )
					end
					if p == color then retcolor = p end
				end
			end
		end
	end
	return tree, retcolor
end

local childs = {}

n=0

local function parse_node(tbl, parent)
	n = n+1
	for k,v in ipairs(tbl.content) do
		local name = table.concat(v.name, " ")

		gv.setv(N, 'color', v.color == "N" and "black" or "white")
		gv.setv(E, 'headlabel', v.p)
		gv.setv(E, 'labeldistance', '2.0')

		if nolinks then
			child = gv.node(gr, n)
		else
			child = gv.node(gr, name)
		end

		gv.setv(child, 'label', name)


		if parent then gv.edge(parent, child) end

		parse_node(v, child)
		n = n+1
	end
end

gr = gv.digraph("G")
E = gv.protoedge(gr)
N = gv.protonode(gr)

gv.setv(gr, 'bgcolor', 'gray')
gv.setv(N, 'color', 'gray')

main = gv.node(gr, table.concat(piles, " ") )

local miaou = {}

miaou.content = add_node(piles, coups, main, "N")
miaou.name = table.concat(piles, " ")

local tmpcol = "black"
for k,v in ipairs(miaou.content) do
	if v.color == "B" then tmpcol = "white" end
end

child = gv.node(gr, miaou.name)
gv.setv(child, 'color', tmpcol)

parse_node(miaou, child)

gv.layout(gr, "dot")
gv.render(gr, "pdf")
