<?php
// Written by Mary Fries, starting Nov 9, 2015, last editted May 3, 2016

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
	
	// Check for LO table & either create it or clear it
	$sql = "SELECT * FROM information_schema.tables WHERE table_schema = 'Crawl_Standards_List' AND table_name = 'LOs'";
	$result = $conn->query($sql);	
	if ($result->num_rows > 0) {
		mysqli_query($conn, "DELETE FROM LOs");
	} else {
		$sql = "CREATE TABLE LOs (Filename VARCHAR(150), Standard VARCHAR(20), PageName VARCHAR(100), WholeStandard VARCHAR(300))";
		$result = $conn->query($sql);	
	}
	
	// Check for EK table & either create it or clear it
	$sql = "SELECT * FROM information_schema.tables WHERE table_schema = 'Crawl_Standards_List' AND table_name = 'EKs'";
	$result = $conn->query($sql);	
	if ($result->num_rows > 0) {
		mysqli_query($conn, "DELETE FROM EKs");
	} else {
		$sql = "CREATE TABLE EKs (Filename VARCHAR(150), Standard VARCHAR(20), PageName VARCHAR(100), WholeStandard VARCHAR(300))";
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
	global $all_covered_LOs;
	$all_covered_LOs = array();
	global $all_covered_EKs;
	$all_covered_EKs = array();
	
	global $all_EUs;
	$all_EUs = array("1.1", "1.2", "1.3", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "4.1", "4.2", "5.1", "5.2", "5.3", "5.4", "5.5", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4", "7.5");
	global $all_LOs;
	$all_LOs = array("1.1.1", "1.2.1", "1.2.2", "1.2.3", "1.2.4", "1.2.5", "1.3.1", "2.1.1", "2.1.2", "2.2.1", "2.2.2", "2.2.3", "2.3.1", "2.3.2", "3.1.1", "3.1.2", "3.1.3", "3.2.1", "3.2.2", "3.3.1", "4.1.1", "4.1.2", "4.2.1", "4.2.2", "4.2.3", "4.2.4", "5.1.1", "5.1.2", "5.1.3", "5.2.1", "5.3.1", "5.4.1", "5.5.1", "6.1.1", "6.2.1", "6.2.2", "6.3.1", "7.1.1", "7.1.2", "7.2.1", "7.3.1", "7.4.1", "7.5.1", "7.5.2");
	global $all_EKs;
	$all_EKs = array("1.1.1A", "1.1.1B", "1.2.1A", "1.2.1B", "1.2.1C", "1.2.1D", "1.2.1E", "1.2.2A", "1.2.2B", "1.2.3A", "1.2.3B", "1.2.3C", "1.2.4A", "1.2.4B", "1.2.4C", "1.2.4D", "1.2.4E", "1.2.4F", "1.2.5A", "1.2.5B", "1.2.5C", "1.2.5D", "1.3.1A", "1.3.1B", "1.3.1C", "1.3.1D", "1.3.1E", "2.1.1A", "2.1.1B", "2.1.1C", "2.1.1D", "2.1.1E", "2.1.1F", "2.1.1G", "2.1.2A", "2.1.2B", "2.1.2C", "2.1.2D", "2.1.2E", "2.1.2F", "2.2.1A", "2.2.1B", "2.2.1C", "2.2.2A", "2.2.2B", "2.2.3A", "2.2.3B", "2.2.3C", "2.2.3D", "2.2.3E", "2.2.3F", "2.2.3G", "2.2.3H", "2.2.3I", "2.2.3J", "2.2.3K", "2.3.1A", "2.3.1B", "2.3.1C", "2.3.1D", "2.3.2A", "2.3.2B", "2.3.2C", "2.3.2D", "2.3.2E", "2.3.2F", "2.3.2G", "2.3.2H", "3.1.1A", "3.1.1B", "3.1.1C", "3.1.1D", "3.1.1E", "3.1.2A", "3.1.2B", "3.1.2C", "3.1.2D", "3.1.2E", "3.1.2F", "3.1.3A", "3.1.3B", "3.1.3C", "3.1.3D", "3.1.3E", "3.2.1A", "3.2.1B", "3.2.1C", "3.2.1D", "3.2.1E", "3.2.1F", "3.2.1G", "3.2.1H", "3.2.1I", "3.2.2A", "3.2.2B", "3.2.2C", "3.2.2D", "3.2.2E", "3.2.2F", "3.2.2G", "3.2.2H", "3.3.1A", "3.3.1B", "3.3.1C", "3.3.1D", "3.3.1E", "3.3.1F", "3.3.1G", "3.3.1H", "3.3.1I", "4.1.1A", "4.1.1B", "4.1.1C", "4.1.1D", "4.1.1E", "4.1.1F", "4.1.1G", "4.1.1H", "4.1.1I", "4.1.2A", "4.1.2B", "4.1.2C", "4.1.2D", "4.1.2E", "4.1.2F", "4.1.2G", "4.1.2H", "4.1.2I", "4.2.1A", "4.2.1B", "4.2.1C", "4.2.1D", "4.2.2A", "4.2.2B", "4.2.2C", "4.2.2D", "4.2.3A", "4.2.3B", "4.2.3C", "4.2.4A", "4.2.4B", "4.2.4C", "4.2.4D", "4.2.4E", "4.2.4F", "4.2.4G", "4.2.4H", "5.1.1A", "5.1.1B", "5.1.1C", "5.1.1D", "5.1.1E", "5.1.1F", "5.1.2A", "5.1.2B", "5.1.2C", "5.1.2D", "5.1.2E", "5.1.2F", "5.1.2G", "5.1.2H", "5.1.2I", "5.1.2J", "5.1.3A", "5.1.3B", "5.1.3C", "5.1.3D", "5.1.3E", "5.1.3F", "5.2.1A", "5.2.1B", "5.2.1C", "5.2.1D", "5.2.1E", "5.2.1F", "5.2.1G", "5.2.1H", "5.2.1I", "5.2.1J", "5.2.1K", "5.3.1A", "5.3.1B", "5.3.1C", "5.3.1D", "5.3.1E", "5.3.1F", "5.3.1G", "5.3.1H", "5.3.1I", "5.3.1J", "5.3.1K", "5.3.1L", "5.3.1M", "5.3.1N", "5.3.1O", "5.4.1A", "5.4.1B", "5.4.1C", "5.4.1D", "5.4.1E", "5.4.1F", "5.4.1G", "5.4.1H", "5.4.1I", "5.4.1J", "5.4.1K", "5.4.1L", "5.4.1M", "5.4.1N", "5.5.1A", "5.5.1B", "5.5.1C", "5.5.1D", "5.5.1E", "5.5.1F", "5.5.1G", "5.5.1H", "5.5.1I", "5.5.1J", "6.1.1A", "6.1.1B", "6.1.1C", "6.1.1D", "6.1.1E", "6.1.1F", "6.1.1G", "6.1.1H", "6.1.1I", "6.2.1A", "6.2.1B", "6.2.1C", "6.2.1D", "6.2.2A", "6.2.2B", "6.2.2C", "6.2.2D", "6.2.2E", "6.2.2F", "6.2.2G", "6.2.2H", "6.2.2I", "6.2.2J", "6.2.2K", "6.3.1A", "6.3.1B", "6.3.1C", "6.3.1D", "6.3.1E", "6.3.1F", "6.3.1G", "6.3.1H", "6.3.1I", "6.3.1J", "6.3.1K", "6.3.1L", "6.3.1M", "7.1.1A", "7.1.1B", "7.1.1C", "7.1.1D", "7.1.1E", "7.1.1F", "7.1.1G", "7.1.1H", "7.1.1I", "7.1.1J", "7.1.1K", "7.1.1L", "7.1.1M", "7.1.1N", "7.1.1O", "7.1.2A", "7.1.2B", "7.1.2C", "7.1.2D", "7.1.2E", "7.1.2F", "7.1.2G", "7.2.1A", "7.2.1B", "7.2.1C", "7.2.1D", "7.2.1E", "7.2.1F", "7.2.1G", "7.3.1A", "7.3.1B", "7.3.1C", "7.3.1D", "7.3.1E", "7.3.1F", "7.3.1G", "7.3.1H", "7.3.1I", "7.3.1J", "7.3.1K", "7.3.1L", "7.3.1M", "7.3.1N", "7.3.1O", "7.3.1P", "7.3.1Q", "7.4.1A", "7.4.1B", "7.4.1C", "7.4.1D", "7.4.1E", "7.5.1A", "7.5.1B", "7.5.1C", "7.5.2A", "7.5.2B");

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
			//NOTE: TO FIX: this breaks if there is a URL of http://bjc.edc.org; why does line 56-59 not work here?
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

// LEARNING OBJECTIVES
echo "\t\t<hr />\n\t\t<h2>Learning<a name='LO' class='anchor'>&nbsp;</a>Objectives</h2>\n";
crawl_all_urls_for_stnds ("LO", $all_covered_LOs);
cleanup_stnds_list($all_covered_LOs); // clean up list
show_covered_stnds ($all_LOs, $all_covered_LOs, "LO"); // show covered
show_and_count_missing_stnds ($all_LOs, $all_covered_LOs, "LO", 5); // show and count missing

// ESSENTIAL KNOWLEDGE
echo "\t\t<hr />\n\t\t<h2>Essential<a name='EK' class='anchor'>&nbsp;</a>Knowledge</h2>\n";
crawl_all_urls_for_stnds ("EK", $all_covered_EKs);
cleanup_stnds_list($all_covered_EKs); // clean up list
show_covered_stnds ($all_EKs, $all_covered_EKs, "EK"); // show covered
show_and_count_missing_stnds ($all_EKs, $all_covered_EKs, "EK", 6); // show and count missing

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
	   case "LO": $stnd_length = 8; break;
	   case "EK": $stnd_length = 9; break;
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

/*function make_section_footer($input_unit) {
	global $active_unit;
	if ($input_unit != $active_unit) {
		echo "</div>\n"; // end hidden toggle div		
	}
}*/

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

// ORDERED EUs and LOs WITH UNIT NAMES FOR COLLEGE BOARD CURRIULUM MAP
echo "\t\t<hr>\n\t\t<h2>Ordered<a name='map' class='anchor'>&nbsp;</a>EUs and LOs for Pasting into College Board Curriculum Map</h2>\n";
echo "\t\t<table class=\"bordered\">\n";
$EU = "";
foreach  ($all_LOs as $LO) {
	$LO_units = populate_stnds_list($LO, "LO");
	if ($EU == substr($LO, 0, 3)) {
		echo "\t\t\t<tr>\n\t\t\t\t<td width='100px'></td><td width='100px'></td><td width='100px'>LO " . $LO . "</td>\n\t\t\t\t<td>" . $LO_units . "</td>\n\t\t\t</tr>\n";
	} else {
		$EU = substr($LO, 0, 3);
		$EU_units = populate_stnds_list($EU, "EU");
		echo "\t\t\t<tr>\n\t\t\t\t<td width='100px'>EU " . $EU . "</td><td width='100px'>" . $EU_units . "</td><td width='100px'>LO " . $LO . "</td>\n\t\t\t\t<td>" . $LO_units . "</td>\n\t\t\t</tr>\n";
	}
}
echo "\t\t</table>\n";

// define function to create list of units for inputed stanard (for curriculum map_
function populate_stnds_list ($standard, $type){
	$stnd_units = "";
	// gather data for each standards
	$sql = "SELECT Filename FROM " . $type . "s WHERE Standard = '" . $type . " " . $standard . "' and PageName LIKE '%Teacher Guide%'";
	global $conn;
	$result = $conn->query($sql);
	if ($result->num_rows > 0) {
		while ($row = $result->fetch_assoc()) {
			$new_stnd_unit = re_to_AP(substr($row["Filename"], strpos($row["Filename"], "teaching-guide/") + 15, 2));
			if (lastchr($new_stnd_unit) != lastchr($stnd_units)) {
				if (strlen($stnd_units) > 0) {
					$stnd_units .= ", " . $new_stnd_unit;
				} else {
					$stnd_units .= $new_stnd_unit;
				}
			}
		}
	}	
	return $stnd_units;
} // end populate_stnds_list definition

// ORDERED LOs and EKs WITH PAGE NAMES FOR LL SPREADSHEET
echo "\t\t<hr>\n\t\t<h2>Ordered<a name='ordered' class='anchor'>&nbsp;</a>LOs and EKs for Pasting into Learning List Spreadsheet</h2>\n";
echo "\t\t<table class=\"bordered\">\n";
foreach  ($all_LOs as $LO) {
	global $conn;
	// create table rows for each LO
	$sql = "SELECT PageName FROM LOs WHERE Standard = 'LO " . $LO . "' and PageName NOT LIKE '%Teacher Guide%'";
	$result = $conn->query($sql);
	create_spreadsheet_row ("LO " . $LO, $result, "ordered");
	// create table rows for each EK
	$relevant_EKs = array();
	foreach  ($all_EKs as $EK) {if (substr($EK, 0, 5) == $LO) {array_push($relevant_EKs, $EK);}}
	foreach  ($relevant_EKs as $EK) {
		$sql = "SELECT PageName FROM EKs WHERE Standard = 'EK " . $EK . "' and PageName NOT LIKE '%Teacher Guide%'";
		$result = $conn->query($sql);
		create_spreadsheet_row ("EK " . $EK, $result, "ordered");
	}
}
echo "\t\t</table>\n";

// LIST OF LOs UNDER EACH CTP FOR LL SPREADSHEET
echo "\t\t<hr>\n\t\t<h2>List<a name='CTP' class='anchor'>&nbsp;</a>of LOs under each CTPs for Further Work before Entry into LL Spreadsheet</h2>\n";
echo "\t\t<table class=\"bordered\">\n";
//global $conn;
// create table rows for each LO
for ($cpt_num = 1; $cpt_num <= 6; $cpt_num++) {
	$sql = "SELECT DISTINCT Filename, PageName, WholeStandard FROM LOs WHERE WholeStandard LIKE '%[P" . $cpt_num . "]%' ORDER BY WholeStandard";
	$result = $conn->query($sql);
	switch($cpt_num) {
		case 1: echo "\t\t\t<tr><td colspan='3'>P1: Connecting Computing - Developments in computing have far-reaching effects on society and have led to significant innovations. The developments have implications for individuals, society, commercial markets, and innovation. Students in this course study these effects, and they learn to draw connections between different computing concepts. Students are expected to:<ul><li>P1.1. Identify impacts of computing.</li><li>P1.2. Describe connections between people and computing.</li><li>P1.3. Explain connections between computing concepts.</li></ul></td></tr>\n"; break;
		case 2: echo "\t\t\t<tr><td colspan='3'>P2: Creating Computational Artifacts - Computing is a creative discipline in which creation takes many forms, such as remixing digital music, generating animations, developing Web sites, and writing programs. Students in this course engage in the creative aspects of computing by designing and developing interesting computational artifacts as well as by applying computing techniques to creatively solve problems. Students are expected to:<ul><li>P2.1. Create an artifact with a practical, personal, or societal intent.</li><li>P2.2. Select appropriate techniques to develop a computational artifact.</li><li>P2.3. Use appropriate algorithmic and information management principles.</li></ul></td></tr>\n"; break;
		case 3: echo "\t\t\t<tr><td colspan='3'>P3: Abstracting -  Computational thinking requires understanding and applying abstraction at multiple levels, such as privacy in social networking applications, logic gates and bits, and the human genome project. Students in this course use abstraction to develop models and simulations of natural and artificial phenomena, use them to make predictions about the world, and analyze their efficacy and validity. Students are expected to:<ul><li>P3.1. Explain how data, information, or knowledge is represented for computational use.</li><li>P3.2. Explain how abstractions are used in computation or modeling.</li><li>P3.3. Identify abstractions.</li><li>P3.4. Describe modeling in a computational context.</li></ul></td></tr>\n"; break;
		case 4: echo "\t\t\t<tr><td colspan='3'>P4: Analyzing Problems and Artifacts -  The results and artifacts of computation and the computational techniques and strategies that generate them can be understood both intrinsically for what they are as well as for what they produce. They can also be analyzed and evaluated by applying aesthetic, mathematical, pragmatic, and other criteria. Students in this course design and produce solutions, models, and artifacts, and they evaluate and analyze their own computational work as well as the computational work others have produced. Students are expected to:<ul><li>P4.1. Evaluate a proposed solution to a problem.</li><li>P4.2. Locate and correct errors.</li><li>P4.3. Explain how an artifact functions.</li><li>P4.4. Justify appropriateness and correctness of a solution, model, or artifact.</li></ul></td></tr>\n"; break;
		case 5: echo "\t\t\t<tr><td colspan='3'>P5: Communicating -  Students in this course describe computation and the impact of technology and computation, explain and justify the design and appropriateness of their computational choices, and analyze and describe both computational artifacts and the results or behaviors of such artifacts. Communication includes written and oral descriptions supported by graphs, visualizations, and computational analysis. Students are expected to:<ul><li>P5.1. Explain the meaning of a result in context.</li><li>P5.2. Describe computation with accurate and precise language, notations, or visualizations.</li><li>P5.3. Summarize the purpose of a computational artifact.</li></ul></td></tr>\n"; break;
		case 6: echo "\t\t\t<tr><td colspan='3'>P6: Collaborating -  Innovation can occur when people work together or independently. People working collaboratively can often achieve more than individuals working alone. Learning to collaborate effectively includes drawing on diverse perspectives, skills, and the backgrounds of peers to address complex and open-ended problems. Students in this course collaborate on a number of activities, including investigation of questions using data sets and in the production of computational artifacts. Students are expected to:<ul><li>P6.1: Collaborate with another student in solving a computational problem.</li><li>P6.2. Collaborate with another student in producing an artifact.</li><li>P6.3. Share the workload by providing individual contributions to an overall collaborative effort.</li><li>P6.4. Foster a constructive, collaborative climate by resolving conflicts and facilitating the contributions of a partner or team member.</li><li>P6.5. Exchange knowledge and feedback with a partner or team member.</li><li>P6.6. Review and revise their work as needed to create a high-quality artifact.</li></ul></td></tr>\n"; break;
	}
	create_spreadsheet_row ("P" . $cpt_num, $result, "ctps");
}
echo "\t\t</table>\n";

// define function to create row in College Board Curriculum Map
function create_map_row ($td_stnd, $result_of_query) {
	if ($result_of_query->num_rows > 0) {
		while ($row = $result_of_query->fetch_assoc()) {
			echo "\t\t\t<tr>\n\t\t\t\t<td width='100px'></td><td width='100px'></td><td width='100px'>" . $td_stnd . "</td>\n\t\t\t\t<td>" . substr($row["Filename"], strpos($row["Filename"], "teaching-guide/") - 15, 2) . "</td>\n\t\t\t</tr>\n";
		}
	}
} // end create_map_row definition

// define function to create row in LL Spreadsheet
function create_spreadsheet_row ($td_stnd, $result_of_query, $purpose) {
	if ($result_of_query->num_rows > 0) {
		$td_page_count = 0; // counter to check if it's the last page
		$td_pages = "";
		$standard = "";
		while ($row = $result_of_query->fetch_assoc()) {
			$td_page_count++;
			if ($purpose == "ordered") {
				$td_pages = $td_pages . $row["PageName"];
				if ($td_page_count < $result_of_query->num_rows) { $td_pages = $td_pages . "; ";} // add semicolons up until the last page
			} elseif ($purpose == "ctps") {
				if ($standard == $row["WholeStandard"]) { // if we are still on the same LO
					$td_pages = $td_pages . "<a href='" . $row["Filename"] . "' target=\"_blank\">" . $row["PageName"] . "</a>; ";
				} else {
					$standard = $row["WholeStandard"];
					$td_pages = $td_pages . "<br />" . $standard . " &mdash; " . "<a href='" . $row["Filename"] . "' target=\"_blank\">" . $row["PageName"] . "</a>; ";
				}
			}
		}
	} else {
		$td_pages = "0 results";
		$td_page_count = 0;
	}
	if (substr($td_stnd, 0, 2) == "LO") {$stnd_color = "blue";} else {$stnd_color = "yellow";}
	if ($td_pages == "0 results") {$stnd_pages = "red";} else {$stnd_pages = "white";}
	echo "\t\t\t<tr>\n\t\t\t\t<td width='100px' bgcolor='" . $stnd_color . "'>" . $td_stnd . "</td>\n\t\t\t\t<td bgcolor='" . $stnd_pages . "'>" . $td_pages . "</td>\n\t\t\t\t<td bgcolor='" . $stnd_pages . "'>" . $td_page_count . "</td>\n\t\t\t</tr>\n";
} // end create_spreadsheet_row definition

// add HTML Page Footer
insert_html_foot();
function insert_html_foot() {
	echo "\t</body>\n</html>";
}

// Close SQL connection
$conn->close();

?>