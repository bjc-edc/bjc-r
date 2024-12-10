#! /bin/csh
set CURRENT='utilities/summaries/'
foreach X (1 2 3 4 5 6 7 8)
  set Y=`grep bjc/$X $CURRENT/topics`
  # $CURRENT/vocab $1 "$Y" -c ${X}*/[0-9]*/[0-9]*
  # $CURRENT/vocab $1 "$Y" -p ${X}*/[0-9]*/[0-9]*
  $CURRENT/vocab $1 "$Y" ${X}*/[0-9]*/[0-9]*
  echo $X
end
