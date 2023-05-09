image_file=$2
xml_file=$1
xml_data=$(cat $xml_file)
url_encoded=$(jq -rn --arg x "$xml_data" '$x|@uri')
snap_marker="Data	Payload	Embedded"
exiftool -Comment="${snap_marker}${url_encoded}${snap_marker}" $image_file
