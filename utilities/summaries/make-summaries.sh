#! /bin/csh
set CURRENT='utilities/summaries/'
cd cur/programming/
rm -f $CURRENT/index-presort
foreach Z (vocab exam assessment-data)
$CURRENT/vocab.sh $Z
echo $Z
end
sort -f $CURRENT/index-presort | uniq -i > $CURRENT/index-sorted
echo sort
$CURRENT/index -c
echo index
