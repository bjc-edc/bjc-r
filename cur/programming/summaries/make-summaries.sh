#! /bin/csh
cd ..
rm -f summaries/index-presort
foreach Z (vocab exam assessment-data)
summaries/vocab.sh $Z
echo $Z
end
sort -f summaries/index-presort | uniq -i > summaries/index-sorted
echo sort
summaries/index
echo index
