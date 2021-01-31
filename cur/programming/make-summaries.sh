#! /bin/csh
rm summaries/index-presort
foreach Z (vocab exam assessment-data)
vocab.sh $Z
end
sort summaries/index-presort | uniq > summaries/index-sorted
