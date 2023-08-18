<?php
// Written by Mary Fries, starting Nov 9, 2015, revised for 202 standards Jan, 2019

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
function initialize_vars() {
	global $seed_url;
	$seed_url = "http://localhost/bjc-r/course/bjc4nyc.html";
	global $found_urls;
	$found_urls = array($seed_url);
	global $crawled_urls;
	$crawled_urls = array();
	global $unit;
	$unit = "";
	
	// new standards array initialization
    global $all_covered_newEUs;
	$all_covered_newEUs = array();
	global $all_covered_newLOs;
	$all_covered_newLOs = array();
	global $all_covered_newEKs;
	$all_covered_newEKs = array();
	global $all_newEUs;
	$all_newEUs = array("CRD-1", "CRD-2", "DAT-1", "DAT-2", "AAP-1", "AAP-2", "AAP-3", "AAP-4", "CSN-1", "CSN-2", "IOC-1", "IOC-2");
	global $all_newLOs;
	$all_newLOs = array("CRD-1.A", "CRD-1.B", "CRD-1.C", "CRD-2.A", "CRD-2.B", "CRD-2.C", "CRD-2.D", "CRD-2.E", "CRD-2.F", "CRD-2.G", "CRD-2.H", "CRD-2.I", "CRD-2.J", "DAT-1.A", "DAT-1.B", "DAT-1.C", "DAT-1.D", "DAT-2.A", "DAT-2.B", "DAT-2.C", "DAT-2.D", "DAT-2.E", "AAP-1.A", "AAP-1.B", "AAP-1.C", "AAP-1.D", "AAP-2.A", "AAP-2.B", "AAP-2.C", "AAP-2.D", "AAP-2.E", "AAP-2.F", "AAP-2.G", "AAP-2.H", "AAP-2.I", "AAP-2.J", "AAP-2.K", "AAP-2.L", "AAP-2.M", "AAP-2.N", "AAP-2.O", "AAP-2.P", "AAP-3.A", "AAP-3.B", "AAP-3.C", "AAP-3.D", "AAP-3.E", "AAP-3.F", "AAP-4.A", "AAP-4.B", "CSN-1.A", "CSN-1.B", "CSN-1.C", "CSN-1.D", "CSN-1.E", "CSN-2.A", "CSN-2.B", "CSN-2.C", "IOC-1.A", "IOC-1.B", "IOC-1.C", "IOC-1.D", "IOC-1.E", "IOC-1.F", "IOC-2.A", "IOC-2.B", "IOC-2.C");
	global $all_newEKs;
	$all_newEKs = array("CRD-1.A.1", "CRD-1.A.2", "CRD-1.A.3", "CRD-1.A.4", "CRD-1.A.5", "CRD-1.A.6", "CRD-1.B.1", "CRD-1.B.2", "CRD-1.C.1", "CRD-1.C.2", "CRD-2.A.1", "CRD-2.A.2", "CRD-2.B.1", "CRD-2.B.2", "CRD-2.B.3", "CRD-2.B.4", "CRD-2.B.5", "CRD-2.C.1", "CRD-2.C.2", "CRD-2.C.3", "CRD-2.C.4", "CRD-2.C.5", "CRD-2.C.6", "CRD-2.D.1", "CRD-2.D.2", "CRD-2.E.1", "CRD-2.E.2", "CRD-2.E.3", "CRD-2.E.4", "CRD-2.F.1", "CRD-2.F.2", "CRD-2.F.3", "CRD-2.F.4", "CRD-2.F.5", "CRD-2.F.6", "CRD-2.F.7", "CRD-2.G.1", "CRD-2.G.2", "CRD-2.G.3", "CRD-2.G.4", "CRD-2.G.5", "CRD-2.H.1", "CRD-2.H.2", "CRD-2.I.1", "CRD-2.I.2", "CRD-2.I.3", "CRD-2.I.4", "CRD-2.I.5", "CRD-2.J.1", "CRD-2.J.2", "CRD-2.J.3", "DAT-1.A.1", "DAT-1.A.2", "DAT-1.A.3", "DAT-1.A.4", "DAT-1.A.5", "DAT-1.A.6", "DAT-1.A.7", "DAT-1.A.8", "DAT-1.A.9", "DAT-1.A.10", "DAT-1.B.1", "DAT-1.B.2", "DAT-1.B.3", "DAT-1.C.1", "DAT-1.C.2", "DAT-1.C.3", "DAT-1.C.4", "DAT-1.C.5", "DAT-1.D.1", "DAT-1.D.2", "DAT-1.D.3", "DAT-1.D.4", "DAT-1.D.5", "DAT-1.D.6", "DAT-1.D.7", "DAT-1.D.8", "DAT-2.A.1", "DAT-2.A.2", "DAT-2.A.3", "DAT-2.A.4", "DAT-2.A.5", "DAT-2.B.1", "DAT-2.B.2", "DAT-2.B.3", "DAT-2.B.4", "DAT-2.B.5", "DAT-2.C.1", "DAT-2.C.2", "DAT-2.C.3", "DAT-2.C.4", "DAT-2.C.5", "DAT-2.C.6", "DAT-2.C.7", "DAT-2.C.8", "DAT-2.D.1", "DAT-2.D.2", "DAT-2.D.3", "DAT-2.D.4", "DAT-2.D.5", "DAT-2.D.6", "DAT-2.E.1", "DAT-2.E.2", "DAT-2.E.3", "DAT-2.E.4", "DAT-2.E.5", "AAP-1.A.1", "AAP-1.A.2", "AAP-1.A.3", "AAP-1.A.4", "AAP-1.B.1", "AAP-1.B.2", "AAP-1.C.1", "AAP-1.C.2", "AAP-1.C.3", "AAP-1.C.4", "AAP-1.D.1", "AAP-1.D.2", "AAP-1.D.3", "AAP-1.D.4", "AAP-1.D.5", "AAP-1.D.6", "AAP-1.D.7", "AAP-1.D.8", "AAP-2.A.1", "AAP-2.A.2", "AAP-2.A.3", "AAP-2.A.4", "AAP-2.B.1", "AAP-2.B.2", "AAP-2.B.3", "AAP-2.B.4", "AAP-2.B.5", "AAP-2.B.6", "AAP-2.B.7", "AAP-2.C.1", "AAP-2.C.2", "AAP-2.C.3", "AAP-2.C.4", "AAP-2.C.5", "AAP-2.D.1", "AAP-2.D.2", "AAP-2.E.1", "AAP-2.E.2", "AAP-2.E.3", "AAP-2.F.1", "AAP-2.F.2", "AAP-2.F.3", "AAP-2.F.4", "AAP-2.F.5", "AAP-2.G.1", "AAP-2.H.1", "AAP-2.H.2", "AAP-2.H.3", "AAP-2.I.1", "AAP-2.I.2", "AAP-2.J.1", "AAP-2.K.1", "AAP-2.K.2", "AAP-2.K.3", "AAP-2.K.4", "AAP-2.K.5", "AAP-2.L.1", "AAP-2.L.2", "AAP-2.L.3", "AAP-2.L.4", "AAP-2.L.5", "AAP-2.M.1", "AAP-2.M.2", "AAP-2.M.3", "AAP-2.N.1", "AAP-2.N.2", "AAP-2.O.1", "AAP-2.O.2", "AAP-2.O.3", "AAP-2.O.4", "AAP-2.O.5", "AAP-2.P.1", "AAP-2.P.2", "AAP-2.P.3", "AAP-3.A.1", "AAP-3.A.2", "AAP-3.A.3", "AAP-3.A.4", "AAP-3.A.5", "AAP-3.A.6", "AAP-3.A.7", "AAP-3.A.8", "AAP-3.A.9", "AAP-3.B.1", "AAP-3.B.2", "AAP-3.B.3", "AAP-3.B.4", "AAP-3.B.5", "AAP-3.B.6", "AAP-3.C.1", "AAP-3.C.2", "AAP-3.D.1", "AAP-3.D.2", "AAP-3.D.3", "AAP-3.D.4", "AAP-3.D.5", "AAP-3.E.1", "AAP-3.E.2", "AAP-3.F.1", "AAP-3.F.2", "AAP-3.F.3", "AAP-3.F.4", "AAP-3.F.5", "AAP-3.F.6", "AAP-3.F.7", "AAP-3.F.8", "AAP-4.A.1", "AAP-4.A.2", "AAP-4.A.3", "AAP-4.A.4", "AAP-4.A.5", "AAP-4.A.6", "AAP-4.A.7", "AAP-4.A.8", "AAP-4.A.9", "AAP-4.B.1", "AAP-4.B.2", "AAP-4.B.3", "CSN-1.A.1", "CSN-1.A.2", "CSN-1.A.3", "CSN-1.A.4", "CSN-1.A.5", "CSN-1.A.6", "CSN-1.A.7", "CSN-1.A.8", "CSN-1.B.1", "CSN-1.B.2", "CSN-1.B.3", "CSN-1.B.4", "CSN-1.B.5", "CSN-1.B.6", "CSN-1.B.7", "CSN-1.C.1", "CSN-1.C.2", "CSN-1.C.3", "CSN-1.C.4", "CSN-1.D.1", "CSN-1.D.2", "CSN-1.D.3", "CSN-1.E.1", "CSN-1.E.2", "CSN-1.E.3", "CSN-1.E.4", "CSN-1.E.5", "CSN-1.E.6", "CSN-1.E.7", "CSN-2.A.1", "CSN-2.A.2", "CSN-2.A.3", "CSN-2.B.1", "CSN-2.B.2", "CSN-2.B.3", "CSN-2.B.4", "CSN-2.C.1", "CSN-2.C.2", "CSN-2.C.3", "CSN-2.C.4", "CSN-2.C.5", "IOC-1.A.1", "IOC-1.A.2", "IOC-1.A.3", "IOC-1.A.4", "IOC-1.A.5", "IOC-1.B.1", "IOC-1.B.2", "IOC-1.B.3", "IOC-1.B.4", "IOC-1.B.5", "IOC-1.B.6", "IOC-1.C.1", "IOC-1.C.2", "IOC-1.C.3", "IOC-1.C.4", "IOC-1.C.5", "IOC-1.D.1", "IOC-1.D.2", "IOC-1.D.3", "IOC-1.E.1", "IOC-1.E.2", "IOC-1.E.3", "IOC-1.E.4", "IOC-1.E.5", "IOC-1.E.6", "IOC-1.F.1", "IOC-1.F.2", "IOC-1.F.3", "IOC-1.F.4", "IOC-1.F.5", "IOC-1.F.6", "IOC-1.F.7", "IOC-1.F.8", "IOC-1.F.9", "IOC-1.F.10", "IOC-1.F.11", "IOC-2.A.1", "IOC-2.A.2", "IOC-2.A.3", "IOC-2.A.4", "IOC-2.A.5", "IOC-2.A.6", "IOC-2.A.7", "IOC-2.A.8", "IOC-2.A.9", "IOC-2.A.10", "IOC-2.A.11", "IOC-2.A.12", "IOC-2.A.13", "IOC-2.A.14", "IOC-2.A.15", "IOC-2.B.1", "IOC-2.B.2", "IOC-2.B.3", "IOC-2.B.4", "IOC-2.B.5", "IOC-2.B.6", "IOC-2.B.7", "IOC-2.B.8", "IOC-2.B.9", "IOC-2.B.10", "IOC-2.C1", "IOC-2.C2", "IOC-2.C3", "IOC-2.C4", "IOC-2.C5", "IOC-2.C6", "IOC-2.C7");
} // end function definition

// display intro text for user
intro_text();
function intro_text() {
	echo "\t\t<div class=\"sidenote\" style=\"position: fixed; top: 80px; right:20px;\">\n\t\t\t<p><a href=\"#hint-TOC\" data-toggle=\"collapse\">Table of Contents...</a></p>\n\t\t\t<div id=\"hint-TOC\" class=\"collapse\"><ul><li><a href=\"#top\">Back to Top</a></li><br /><h4>New standards:</h4><br /><h4>Old standards:</h4><li>EUs<ul><li><a href='#EU'>EUs by TG Lab Page</a></li><li><a href='#allEU'>Covered EUs</a></li><li><a href='#missingEU'>Missing EUs</a></li></ul></li><li>LOs<ul><li><a href='#LO'>LOs by TG Lab Page</a></li><li><a href='#allLO'>Covered LOs</a></li><li><a href='#missingLO'>Missing LOs</a></li></ul></li><li>EKs<ul><li><a href='#EK'>EKs by TG Lab Page</a></li><li><a href='#allEK'>Covered EKs</a></li><li><a href='#missingEK'>Missing EKs</a></li></ul></li><li><a href='#map'>Ordered EUs/LOs List for CB Map</a></li><li><a href='#ordered'>Ordered LOs/EKs List for LL</a></li><li><a href='#CTP'>CTP Lists</a></li></ul></div>\n\t\t\t<p><a href=\"#hint-Links\" data-toggle=\"collapse\">Other Links...</a></p>\n\t\t\t<div id=\"hint-Links\" class=\"collapse\"><ul><li><a href=\"https://docs.google.com/spreadsheets/d/1Iw3-TINMp_-qJ10688pfg9ACDjYAyWTWMSG_Op8sQOw/edit#gid=477558311\" target=\"_blank\">NonCorrespondenceList</a></li><li><a href=\"https://secure-media.collegeboard.org/digitalServices/pdf/ap/ap-computer-science-principles-course-and-exam-description.pdf\" target=\"_blank\">Framework</a></li><li><a href=\"https://www2.cs.duke.edu/csed/csprinciples/framework/\" target=\"_blank\">Lookup</a></li></ul></div>\n\t\t</div>\n";
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

echo "\t\t<h1>2020 Standards</h1>\n";

// New LEARNING OBJECTIVES
echo "\t\t<h2><a href='#hint-new-LOs' data-toggle='collapse' title='New LOs'>New Learning Objectives</a><a name='newLO' class='anchor'>&nbsp;</a></h2>\n";
echo "\t\t<div id='hint-new-LOs' class='collapse'>\n";
crawl_all_urls_for_stnds ("newLO", $all_covered_newLOs);
cleanup_stnds_list($all_covered_newLOs); // clean up list
show_covered_stnds ($all_newLOs, $all_covered_newLOs, "newLO"); // show covered
show_and_count_missing_stnds ($all_newLOs, $all_covered_newLOs, "newLO", 7); // show and count missing
echo "\t\t</div>\n";

// New ESSENTIAL KNOWLEDGE
echo "\t\t<h2><a href='#hint-new-EKs' data-toggle='collapse' title='New EKs'>New Essential Knowledge</a><a name='newEK' class='anchor'>&nbsp;</a></h2>\n";
echo "\t\t<div id='hint-new-EKs' class='collapse'>\n";
crawl_all_urls_for_stnds ("newEK", $all_covered_newEKs);
cleanup_stnds_list($all_covered_newEKs); // clean up list
show_covered_stnds ($all_newEKs, $all_covered_newEKs, "newEK"); // show covered
show_and_count_missing_stnds ($all_newEKs, $all_covered_newEKs, "newEK", 9); // show and count missing
echo "\t\t</div>\n";

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
	/*switch ($input_stnd) {
	   case "EU": $stnd_length = 6; break;
	   case "LO": $stnd_length = 8; break;
	   case "EK": $stnd_length = 9; break;
	   /* Junk this if not needed
       case "newEU": $stnd_length = 5; break;
	   case "newLO": $stnd_length = 7; break;
	   case "newEK": $stnd_length = 9; break; * /
	}*/
	
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
	global $all_newEKs;
	
	// Goal: load $found_standards[$i] with all the new standards on the $input_url page
    // new version for 2020 standards
    if (substr($standard, 0, -2) == "new") {
        $file_lines = file($input_url); // loads topic file into $file_lines array
		foreach ($file_lines as $i => $line) {
			if (strpos($line, "CRD") || strpos($line, "DAT") || strpos($line, "AAP") || strpos($line, "CSN") || strpos($line, "IOC")) {
                foreach ($all_newEKs as $j => $newEK) {
                    if (strpos($line, $newEK)) {
                        $found_standards[$i] = $newEK;
                    }
                }
            }
        }
    } elseif (substr($input_url, -4) == "html") { // dump standards on HTML pages into array (old version)
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
  //  if (substr($input_stnd, 0, -2) == "new") {
//        echo $input_stand_list . "<br /><br /><br />";
    //} else {
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
   // }
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