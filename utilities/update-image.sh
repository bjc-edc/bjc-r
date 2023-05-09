image_file=$2
xml_file=$1
url_encode=$(jq -rn --arg x "$(cat $xml_file)" '$x|@uri')
exiftool -Comment="Data	Payload	Embedded${url_encoded}Data	Payload	Embedded" $image_file
