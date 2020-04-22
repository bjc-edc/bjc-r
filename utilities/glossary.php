<?php
// Written by Mary Fries, starting Nov 9, 2015, last editted Mar 6, 2020

// add HTML Site Header
insert_html_head();
function insert_html_head() {
echo "<!doctype html>
<html lang=\"en\">
    <head>
		<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
		<script type=\"text/javascript\" src=\"/bjc-r/llab/loader.js\"></script>
		<title>BJC Site Crawler</title>
    </head>\n\t<body>\n";
}

// call HTML Document Object manager from http://simplehtmldom.sourceforge.net/
include_once('simple_html_dom.php');

// set up mysql connection to DB
setup_mysql();
function setup_mysql() {
	// mysql variables
	$servername = "localhost";
	$username = "root";
	$password = "";
	$dbname = "Crawl_Standards_List";
	
	// make DB connection
	global $conn;
	$conn = new mysqli($servername, $username, $password, $dbname);
	
	// Check connection
	if ($conn->connect_error) {
		die("Connection failed: " . $conn->connect_error);
	} 
	
	// Check for EU table & either create it or clear it
	$sql = "SELECT * FROM information_schema.tables WHERE table_schema = 'Crawl_Standards_List' AND table_name = 'EUs'";
	$result = $conn->query($sql);	
	if ($result->num_rows > 0) {
		mysqli_query($conn, "DELETE FROM EUs");
	} else {
		$sql = "CREATE TABLE EUs (Filename VARCHAR(150), Standard VARCHAR(20), PageName VARCHAR(100), WholeStandard VARCHAR(300))";
		$result = $conn->query($sql);	
	}
	
	
} // end function definition

// make global definitions 
initialize_vars();
function initialize_vars(){
	global $seed_url;
	$seed_url = "http://localhost/bjc-r/course/bjc4nyc.html";
	global $found_urls;
	$found_urls = array($seed_url);
	global $crawled_urls;
	$crawled_urls = array();
	global $unit;
	$unit = "";
	
	global $all_covered_EUs;
	$all_covered_EUs = array();
	
	global $all_EUs;
	$all_EUs = array("1.1", "1.2", "1.3", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "4.1", "4.2", "5.1", "5.2", "5.3", "5.4", "5.5", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4", "7.5");

} // end function definition

// display intro text for user
intro_text();
function intro_text() {
	echo "\t\t<div class=\"sidenote\" style=\"position: fixed; top: 80px; right:20px;\">\n\t\t\t<p><a href=\"#hint-TOC\" data-toggle=\"collapse\">Table of Contents...</a></p>\n\t\t\t<div id=\"hint-TOC\" class=\"collapse\"><ul><li><a href=\"#top\">Back to Top</a></li><li>EUs<ul><li><a href='#EU'>EUs by TG Lab Page</a></li><li><a href='#allEU'>Covered EUs</a></li><li><a href='#missingEU'>Missing EUs</a></li></ul></li><li>LOs<ul><li><a href='#LO'>LOs by TG Lab Page</a></li><li><a href='#allLO'>Covered LOs</a></li><li><a href='#missingLO'>Missing LOs</a></li></ul></li><li>EKs<ul><li><a href='#EK'>EKs by TG Lab Page</a></li><li><a href='#allEK'>Covered EKs</a></li><li><a href='#missingEK'>Missing EKs</a></li></ul></li><li><a href='#map'>Ordered EUs/LOs List for CB Map</a></li><li><a href='#ordered'>Ordered LOs/EKs List for LL</a></li><li><a href='#CTP'>CTP Lists</a></li></ul></div>\n\t\t\t<p><a href=\"#hint-Links\" data-toggle=\"collapse\">Other Links...</a></p>\n\t\t\t<div id=\"hint-Links\" class=\"collapse\"><ul><li><a href=\"https://docs.google.com/spreadsheets/d/1Iw3-TINMp_-qJ10688pfg9ACDjYAyWTWMSG_Op8sQOw/edit#gid=477558311\" target=\"_blank\">NonCorrespondenceList</a></li><li><a href=\"https://secure-media.collegeboard.org/digitalServices/pdf/ap/ap-computer-science-principles-course-and-exam-description.pdf\" target=\"_blank\">Framework</a></li><li><a href=\"https://www2.cs.duke.edu/csed/csprinciples/framework/\" target=\"_blank\">Lookup</a></li></ul></div>\n\t\t</div>\n";
	echo "\t\t<h3>This<a name=\"top\">&nbsp;</a>script crawls for standards on your localhost copy of the repo.</h3><p><small>Please note that:<ul><li>This crawler will catch <em>any</em> standard in our list format <em>even if it's commented out</em>;</li><li>It doesn't differentiate between rewritten copies of the same standard. (If the number of standards found to be \"Missing (determined by subtraction)\"&mdash; subtracting the number covered standards from the actual number of standards&mdash;doesn't match the \"Total Found Missing,\" then slightly rewritten copies are likely the cause.)</li></ul></small></p><hr />\n";
}

// start crawl and report dead links (begins with $seed_url and populates $crawled_urls array)
crawl_for_links($seed_url);
function crawl_for_links($input_url) {
	// initialize local array
	$urls = array();
	
	// check if $input_url is HTML or TOPIC page and dump links into $urls array
	if (substr($input_url, -4) == "html") {
		// crawl for links in HTML pages
		$html_file_lines = new simple_html_dom();
		$html_file_lines -> load_file($input_url);
		foreach($html_file_lines -> find('<a') as $i => $link) {
			$urls[$i] = $link -> href;
		}
		$html_file_lines->clear(); //clearing available memory per: https://www.electrictoolbox.com/php-simple-html-dom-parser-allowed-memory-exhausted/
	} elseif (substr($input_url, -5) == "topic") {
		// crawl for links in TOPIC pages
		$topic_file_lines = file($input_url); // loads topic file into $topic_file_lines array
		foreach ($topic_file_lines as $line_num => $line) {
			if (substr($line, 1, 8) == "resource" or substr($line, 1, 4) == "quiz") {
				$urls[$line_num] = substr(strchr(substr($line, 0, stripos($line, "]")), "["), 1); 	// adds link to $urls array
				$urls = array_values($urls);    // re-indexes $urls
			}	
		}
	}
		
	// set local constants for server address and address length
	$server = "http://".$_SERVER['HTTP_HOST'];
	$server_len = strlen($server);
		
	// clean up $found_urls
	foreach ($urls as $i => $found_url) {
		
		//	make internal links non-relative
		if (substr ($found_url, 0, 6) == "/bjc-r") {
			$urls[$i] = $server.$found_url;
		}
		
		// remove external links
		if (substr($urls[$i], 0, $server_len) != $server) {
			unset($urls[$i]);
		}
		
		// remove topic.html?topic= from TOPIC file URLs 
		if (substr($found_url, -5) == "topic" and strstr($urls[$i], "topic.html?topic=") != "") {
			$urls[$i] = substr($urls[$i], 0, stripos($urls[$i], "topic.html?topic=")).substr(strstr($urls[$i], "topic.html?topic="), 17, strlen($urls[$i]));
		} elseif (strstr($found_url, "?topic=nyc_bjc") != "") { 
		
		// remove other HTML file TOPIC suffixes
            $urls[$i] = substr($urls[$i], 0, stripos($urls[$i], "?topic=nyc_bjc")); //cuts everything after "?topic=nyc_bjc"
			//NOTE: TO FIX: this breaks if there is a URL of http://bjc.edc.org; why does line 56-59 not work here? update: do I mean 143-145 (remove external links)?
		}
	
		// remove MISC files
		if (ends_with($found_url, "xml") or ends_with($found_url, "pdf") or ends_with($found_url, "png") or ends_with($found_url, "pptx") or ends_with($found_url, "csv")) {
			unset($urls[$i]);
		}
		
		// remove Specific files
		if (ends_with($found_url, "ap-standards.html") or ends_with($found_url, "video-list-scratch.html") or ends_with($found_url, "video-list.html") or ends_with($found_url, "updates.html")) {
			unset($urls[$i]);
		}
		
	} //end foreach
	
	// drop hash (#) signs
	foreach ($urls as $i => $url){
		if (stripos($url, "#")) {
			$urls[$i] = substr($url, 0, stripos($url, "#"));
		}
	}

	// remove non-existant files
	foreach ($urls as $i => $url){
		$physical_url = substr($url, strlen($server), strlen($url));
		if (!file_exists($_SERVER["DOCUMENT_ROOT"] . $physical_url)) {
			echo "\t\tDEAD Link: <a href='" . $physical_url . "' target='_blank'>" . $physical_url . "</a> on page: <a href='" . $input_url . "' target='_blank'>" . $input_url . "</a><br />\n";
			unset($urls[$i]);
		}
	}
	
	// update global lists
	global $found_urls;
	$found_urls = array_merge($found_urls, $urls); // adds found $urls to $found_urls

	global $crawled_urls;
	$crawled_urls[count($crawled_urls)] = $input_url; // adds $input_url to $crawled_urls

	// sort global lists
	asort($found_urls);
	asort($crawled_urls);
	
	// remove duplicates from global lists
	$found_urls = array_unique($found_urls);
	$crawled_urls = array_unique($crawled_urls);
	
	// re-index $found_urls
	$found_urls = array_values($found_urls); 	

	// crawl any found pages that haven't been crawled yet (recursive step)
	foreach ($found_urls as $found_url) {
		if (!(in_array($found_url, $crawled_urls))) { // if there's a $found_url that has not been crawled
			crawl_for_links($found_url); // crawl it
		}
	}
} // end function definition

// report data from crawling process
echo "\t\t<p><strong>Total Pages Crawled: " . count($crawled_urls)."</strong></p>\n";
show_crawled_urls ();
function show_crawled_urls () {
	global $html_data_from_crawled_urls;
	$html_data_from_crawled_urls = "";
	global $crawled_urls;
	foreach ($crawled_urls as $crawled_url) {
		$html_data_from_crawled_urls = $html_data_from_crawled_urls . "\t\t\t" . $crawled_url . "<br />\n";
	}
}
echo "\t\t<p><a href='#hint-target' data-toggle='collapse' title='Toggle Crawled URLs'>List of Pages Crawled...</a></p>\n\t\t<div id='hint-target' class='collapse'>\n" . $html_data_from_crawled_urls . "</div><hr />\n";

// ENDURING UNDERSTANDINGS
echo "\t\t<h2>Enduring<a name='EU' class='anchor'>&nbsp;</a>Understandings</h2>\n";
crawl_all_urls_for_stnds ("EU", $all_covered_EUs);
cleanup_stnds_list($all_covered_EUs); // clean up list
show_covered_stnds ($all_EUs, $all_covered_EUs, "EU"); // show covered
show_and_count_missing_stnds ($all_EUs, $all_covered_EUs, "EU", 3); // show and count missing

// define function to check if one string ends with another
function ends_with ($string, $end){
	if (substr($string, -strlen($end)) == $end) {
		return true;
	} else {return false;}
} // end ends_with definition

// define function to crawl $crawled_urls for standards (populates $found_standards array)
function crawl_all_urls_for_stnds($input_stnd, &$input_covered_list) {
	// set up standard length
	$stnd_length = 0;
	switch ($input_stnd) {
	   case "EU": $stnd_length = 6; break;
	   /*case "LO": $stnd_length = 8; break;
	   case "EK": $stnd_length = 9; break;*/
	}
	
	global $crawled_urls;
	foreach ($crawled_urls as $crawled_url) {
		$found_standards = array(); // initialize
		crawl_page_for_standards($crawled_url, $input_stnd); //crawl page for EUs
		global $found_standards;
	
		// Getting TG vs. Student Pages filename
		if (strpos($crawled_url, "/lab-pages/") >= 1) {
			$filename = substr($crawled_url, strpos($crawled_url, "/lab-pages/") + 11);
		} else {
			$filename_noprogramming = substr($crawled_url, strpos($crawled_url, "/programming/") + 13);
			$filename = substr($filename_noprogramming, strpos($filename_noprogramming, "/") + 1);
		}
		
		if (count($found_standards) >= 1){
			//report all found standards
			global $unit;
			$unit = make_section_header($unit, $crawled_url, $input_stnd);
			echo "\t\t\t<strong><a href='" . $crawled_url . "' target='_blank'>" . $filename . "</a> (" . count($found_standards) . ")</strong><br />\n";
			//echo "\t\t\t<strong>" . $filename . "(" . count($found_standards) . ")</strong><br />\n";
			foreach ($found_standards as $found_standard){
				echo "\t\t\t\t" . rtrim($found_standard) . "<br />\n";
				$standard = substr($found_standard, 0, $stnd_length);
				$pagetitle = crawl_for_title($crawled_url);
				global $conn;
				$query = "INSERT INTO " . $input_stnd . "s (Filename, Standard, PageName, WholeStandard) VALUES ('$crawled_url', '$standard', '$pagetitle', '$found_standard')";
				mysqli_query($conn, $query);
				array_push($input_covered_list, $found_standard);
			}
			//make_section_footer($unit);
		}
	}
} // end crawl_all_urls_for_stnds definition

// define function to crawl one URL for standards (populates $found_standards array)
function crawl_page_for_standards($input_url, $standard) {
	global $found_standards;
	
	// dump standards on HTML pages into array
	if (substr($input_url, -4) == "html") {
		// crawl for links in HTML pages
		$file_lines = file($input_url); // loads topic file into $file_lines array
		foreach ($file_lines as $i => $line) {
			if (strpos($line, '<li>' . $standard)) {
				$found_standards[$i] = substr($line, strpos($line, '<li>' . $standard) + 4);
			} elseif (strpos($line, '<li><strong>' . $standard)) {
				$found_standards[$i] = substr($line, strpos($line, '<li><strong>' . $standard) + 12);
			}
		}
	}
} // end crawl_for_standards definition

// define function to make standards section headers
function make_section_header ($input_unit, $input_url, $standard_type) {
	global $active_unit;
	if (strpos($input_url, "/lab-pages/")) {
		$active_unit = substr(substr($input_url, strpos($input_url, "/U") + 1), 0, 2);
		$page_type = " TG ";
	} elseif (strpos($input_url, "/programming/")) {
		$active_unit = "U" . substr(substr($input_url, strpos($input_url, "/programming/") + 13), 0, 1);
		$page_type = " Student Page ";
	}
	if ($input_unit != $active_unit) {
		//echo "\t\t<h3><a href='#hint-" . $standard_type . "-" . $active_unit . "-" . substr($page_type, 1, 1) .  "' data-toggle='collapse'>" . $active_unit . $page_type . $standard_type . "s</a></h3>\n";
		echo "\t\t<h3>" . $active_unit . $page_type . $standard_type . "s</h3>\n";
		//echo "\t\t<div id='#hint-" . $standard_type . "-" . $active_unit . "-" . substr($page_type, 1, 1) .  "' class='collapse'>\n";
		return $active_unit;
	} else {	return $input_unit;}
} // end make_section_header definition

// define function to crawl page for page title
function crawl_for_title($input) {
	$html = file_get_html($input);
	$title = $html->find('title',0);
	return $title->plaintext;
	
} // end crawl_for_title definition

// define function clean up list of standards: sort, remove duplicates, re-index
function cleanup_stnds_list(&$input_covered_list){
	asort($input_covered_list);
	$input_covered_list = array_unique($input_covered_list);
	$input_covered_list = array_values($input_covered_list); 
} // end cleanup_stnds_list definition

// define function display and tally covered standards (and calc what missing should be)
function show_covered_stnds ($input_stnd_list, $input_covered_list, $input_stnd) {
	echo "\t\t<hr /><h2>List of all " . $input_stnd . "s<a name='all" . $input_stnd . "' class='anchor'>&nbsp;</a>Covered</h2>\n";
	foreach ($input_covered_list as $sntd) {echo "\t\t" . rtrim($sntd) . "<br />\n";}
	echo "\t\t<p><strong>" . $input_stnd . "s Found to be Covered: " . count($input_covered_list) . "<br />Actual Number of " . $input_stnd . "s: " . count($input_stnd_list) . "<br />Missing " . $input_stnd . "s (determined by subtraction): " . (count($input_stnd_list) - count($input_covered_list)) . "</strong></p>\n";
} // end show_covered_stnds definition

// define function to display and tally missing standards
function show_and_count_missing_stnds (&$input_stnd_list, $input_covered_list, $input_stnd, $stnd_length) {
	echo "<hr /><h2>List of all <strong>MISSING</strong><a name='missing" . $input_stnd . "' class='anchor'>&nbsp;</a>" . $input_stnd . "s</h2>";
	$missing_stnds = 0;
	foreach ($input_stnd_list as $actual_stnd) {
		$covered = False;
		foreach ($input_covered_list as $stnd) {
			if (substr_compare($stnd, $actual_stnd, 3, $stnd_length) == 0) {
				$covered = True;
				break;
			}
		}
		if (!$covered) {
			echo $actual_stnd . "<br />";
			$missing_stnds++;
		}
	}
	echo "<br /><strong>Total Found Missing " . $input_stnd . "s: " . $missing_stnds . "</strong><br />";
	} // end show_and_count_missing_stnds definition
	
function lastchr($input) { if (strlen($input) > 0){ return substr($input, strlen($input)-1); } }
function re_to_AP($input) { if ($input == "re") { return "Performance Tasks"; } else { return $input; } }

// add HTML Page Footer
insert_html_foot();
function insert_html_foot() {
	echo "\t</body>\n</html>";
}

// Close SQL connection
$conn->close();

?>