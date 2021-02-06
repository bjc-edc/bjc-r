#! /bin/csh
foreach X (1 2 3 4 5 6 7 8)
set Y=`grep bjc/$X summaries/topics`
summaries/vocab $1 "$Y" ${X}*/[0-9]*/[0-9]*
end
