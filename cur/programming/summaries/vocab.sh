#! /bin/csh
foreach X (1 2 3 4 5 6 7 8)
summaries/vocab $1 ${X}*/[0-9]*/[0-9]*
end
