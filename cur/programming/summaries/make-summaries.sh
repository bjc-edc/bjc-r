#! /bin/csh
cd ..
rm -f summaries/index-presort
foreach Z (vocab exam assessment-data)
summaries/vocab.sh $Z
end
sort -f summaries/index-presort | uniq -i > summaries/vocab-index
