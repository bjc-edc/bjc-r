<?php
// Written by Mary Fries, starting Nov 9, 2015, last editted May 3, 2016

// call HTML Document Object manager from http://simplehtmldom.sourceforge.net/
include_once('simple_html_dom.php');

// global definitions 
$seed_url = "http://localhost/bjc-r/course/bjc4nyc.html";
$found_urls = array($seed_url);
$crawled_urls = array();
$unit = "";
$all_covered_EUs = array();
$all_covered_LOs = array();
$all_covered_EKs = array();

// input seed_url into custom procedure
crawl_for_links($seed_url);

// define custom recursive procedure to crawl input page & all pages found on it & on that & so on...
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
	} elseif (substr($input_url, -5) == "topic") {
		// crawl for links in TOPIC pages
		$topic_file_lines = file($input_url); // loads topic file into $topic_file_lines array
		foreach ($topic_file_lines as $line_num => $line) {
			if (substr($line, 1, 8) == "resource" or substr($line, 1, 4) == "quiz") {
				$urls[$line_num] = substr(strchr(substr($line, 0, stripos($line, "]")), "["), 1); 	// adds link to $urls array
				$urls = array_values($urls); 													// re-indexes $urls
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
			$urls[$i] = substr($urls[$i], 0 ,stripos($urls[$i], "topic.html?topic=")).substr(strstr($urls[$i], "topic.html?topic="), 17, strlen($urls[$i]));
		} elseif (strstr($found_url, "?topic=nyc_bjc") != "") { 
		
		// remove other HTML file TOPIC suffixes
			$urls[$i] = substr($urls[$i], 0, stripos($urls[$i], "?topic=nyc_bjc")); //cuts everything after "?topic=nyc_bjc"
		}
	
		// remove MISC files
		if ((substr($found_url, -3) == "xml") or (substr($found_url, -3) == "pdf") or (substr($found_url, -3) == "png") or (substr($found_url, -4) == "pptx") or (substr($found_url, -3) == "csv")) {
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
			echo "<br />" . "DEAD Link: <a href='" . $physical_url . "' target='_blank'>" . $physical_url . "</a> on page: <a href='" . $input_url . "' target='_blank'>" . $input_url . "</a>";
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
	
echo "<br /><br /><strong>Total Pages Crawled: " . count($crawled_urls)."</strong>";

// site indexing complete; begin crawling for standards

echo "<hr /><h3>Welcome to script that crawls for standards from your localhost copy of the repo. Edits to the repo pages will update on this page upon refresh.<br />Please note that:<ul><li>It will catch <em>any</em> standard in our list format <em>even if it's commented out</em> (perhaps I could fix that, but I haven't yet);</li><li>It also doesn't differentiate between rewritten copies of the same standard - in part, because it's a pain to do that and in part, because I don't think we should be rewriting standards at all.</li><li>It also doesn't differentiate between copies of the same standard with sidenotes tucked on the same line (I could probably fix that in the script, but it was easier for me to clean the files themselves).</li></ul><p>In short especially for the EKS, this list can't be fully trusted (it's just a reference) until the TG files are cleaned up and the extra EKs listed there are removed - because those files are read to generate these lists. Enjoy!! --MF</p></h3><hr />";


// input crawled_urls into custom procedure
echo "<h2>Enduring Understandings</h2>";
foreach ($crawled_urls as $crawled_url) {
	$found_standards = array();
	crawl_for_standards(array($crawled_url, "EU"));
	
	if (count($found_standards) >= 1){
		//report all found standards
		if ($unit != substr(substr($crawled_url, strpos($crawled_url, "/U") + 1), 0, 2)) {
			$unit = substr(substr($crawled_url, strpos($crawled_url, "/U") + 1), 0, 2);
			echo "<h3>" . $unit . "</h3>";
		}
		echo "<strong>" . substr($crawled_url, strpos($crawled_url, "/lab-pages/") + 11) . "</strong><br />";
		foreach ($found_standards as $found_standard){
			echo $found_standard . "<br />";
			array_push($all_covered_EUs, $found_standard);
		}
	}
}

// clean up $all_covered_EUs: sort,remove duplicates, re-index
asort($all_covered_EUs);
$all_covered_EUs = array_unique($all_covered_EUs);
$all_covered_EUs = array_values($all_covered_EUs); 	

echo "<hr /><h2>List of all EUs Covered</h2>";

foreach ($all_covered_EUs as $EU) {
	echo $EU . "<br />";
}

// July 2017 bit for finding missing standards
$all_EUs = array("1.1", "1.2", "1.3", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "4.1", "4.2", "5.1", "5.2", "5.3", "5.4", "5.5", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4", "7.5");

echo "<hr /><h2>List of all <strong>MISSING</strong> EUs</h2>";

foreach ($all_EUs as $actual_EU) {
	$covered = False;
	foreach ($all_covered_EUs as $EU) {
		if (substr_compare($EU, $actual_EU, 3, 3) == 0) {
			$covered = True;
			break;
		}
	}
	if (!$covered) {
		echo $actual_EU . "<br />";
	}
}

// Ideally, these would be 3 separte calls to the same function rather than 3 separately typed out near-copies, but I was having trouble with the scope of $found_standards and needed to go eat dinner. Also, there is that ap-standards.html difference in the LO script, but that could easily appear in the funciton for all three... 

// input crawled_urls into custom procedure
echo "<hr /><h2>Learning Objectives</h2>";
foreach ($crawled_urls as $crawled_url) {
	$found_standards = array();
	if ($crawled_url != "http://".$_SERVER['HTTP_HOST'] . "/bjc-r/cur/teaching-guide/AP/ap-standards.html") {
		crawl_for_standards(array($crawled_url, "LO"));
	}
	
	if (count($found_standards) >= 1){
		//report all found standards
		if ($unit != substr(substr($crawled_url, strpos($crawled_url, "/U") + 1), 0, 2)) {
			$unit = substr(substr($crawled_url, strpos($crawled_url, "/U") + 1), 0, 2);
			echo "<h3>" . $unit . "</h3>";
		}
		echo "<strong>" . substr($crawled_url, strpos($crawled_url, "/lab-pages/") + 11) . "</strong><br />";
		foreach ($found_standards as $found_standard){
			echo $found_standard . "<br />";
			array_push($all_covered_LOs, $found_standard);
		}
	}
}

// clean up $all_covered_LOs: sort,remove duplicates, re-index
asort($all_covered_LOs);
$all_covered_LOs = array_unique($all_covered_LOs);
$all_covered_LOs = array_values($all_covered_LOs); 	

echo "<hr /><h2>List of all LOs Covered</h2>";

foreach ($all_covered_LOs as $LO) {
	echo $LO . "<br />";
}

// July 2017 bit for finding missing standards

$all_LOs = array("1.1.1", "1.2.1", "1.2.2", "1.2.3", "1.2.4", "1.2.5", "1.3.1", "2.1.1", "2.1.2", "2.2.1", "2.2.2", "2.2.3", "2.3.1", "2.3.2", "3.1.1", "3.1.2", "3.1.3", "3.2.1", "3.2.2", "3.3.1", "4.1.1", "4.1.2", "4.2.1", "4.2.2", "4.2.3", "4.2.4", "5.1.1", "5.1.2", "5.1.3", "5.2.1", "5.3.1", "5.4.1", "5.5.1", "6.1.1", "6.2.1", "6.2.2", "6.3.1", "7.1.1", "7.1.2", "7.2.1", "7.3.1", "7.4.1", "7.5.1", "7.5.2");

echo "<hr /><h2>List of all <strong>MISSING</strong> LOs</h2>";

foreach ($all_LOs as $actual_LO) {
	$covered = False;
	foreach ($all_covered_LOs as $LO) {
		if (substr_compare($LO, $actual_LO, 3, 5) == 0) {
			$covered = True;
			break;
		}
	}
	if (!$covered) {
		echo $actual_LO . "<br />";
	}
}

// input crawled_urls into custom procedure
echo "<hr /><h2>Essential Knowledge</h2>";
foreach ($crawled_urls as $crawled_url) {
	$found_standards = array();
	crawl_for_standards(array($crawled_url, "EK"));
	
	if (count($found_standards) >= 1){
		//report all found standards
		if ($unit != substr(substr($crawled_url, strpos($crawled_url, "/U") + 1), 0, 2)) {
			$unit = substr(substr($crawled_url, strpos($crawled_url, "/U") + 1), 0, 2);
			echo "<h3>" . $unit . "</h3>";
		}
		echo "<strong>" . substr($crawled_url, strpos($crawled_url, "/lab-pages/") + 11) . "</strong><br />";
		foreach ($found_standards as $found_standard){
			echo $found_standard . "<br />";
			array_push($all_covered_EKs, $found_standard);
		}
	}
}

// clean up $all_covered_EKs: sort,remove duplicates, re-index
asort($all_covered_EKs);
$all_covered_EKs = array_unique($all_covered_EKs);
$all_covered_EKs = array_values($all_covered_EKs); 	

echo "<hr /><h2>List of all EKs Covered</h2>";

foreach ($all_covered_EKs as $EK) {
	echo $EK . "<br />";
}

// July 2017 bit for finding missing standards

$all_EKs = array("1.1.1A", "1.1.1B", "1.2.1A", "1.2.1B", "1.2.1C", "1.2.1D", "1.2.1E", "1.2.2A", "1.2.2B", "1.2.3A", "1.2.3B", "1.2.3C", "1.2.4A", "1.2.4B", "1.2.4C", "1.2.4D", "1.2.4E", "1.2.4F", "1.2.5A", "1.2.5B", "1.2.5C", "1.2.5D", "1.3.1A", "1.3.1B", "1.3.1C", "1.3.1D", "1.3.1E", "2.1.1A", "2.1.1B", "2.1.1C", "2.1.1D", "2.1.1E", "2.1.1F", "2.1.1G", "2.1.2A", "2.1.2B", "2.1.2C", "2.1.2D", "2.1.2E", "2.1.2F", "2.2.1A", "2.2.1B", "2.2.1C", "2.2.2A", "2.2.2B", "2.2.3A", "2.2.3B", "2.2.3C", "2.2.3D", "2.2.3E", "2.2.3F", "2.2.3G", "2.2.3H", "2.2.3I", "2.2.3J", "2.2.3K", "2.3.1A", "2.3.1B", "2.3.1C", "2.3.1D", "2.3.2A", "2.3.2B", "2.3.2C", "2.3.2D", "2.3.2E", "2.3.2F", "2.3.2G", "2.3.2H", "3.1.1A", "3.1.1B", "3.1.1C", "3.1.1D", "3.1.1E", "3.1.2A", "3.1.2B", "3.1.2C", "3.1.2D", "3.1.2E", "3.1.2F", "3.1.3A", "3.1.3B", "3.1.3C", "3.1.3D", "3.1.3E", "3.2.1A", "3.2.1B", "3.2.1C", "3.2.1D", "3.2.1E", "3.2.1F", "3.2.1G", "3.2.1H", "3.2.1I", "3.2.2A", "3.2.2B", "3.2.2C", "3.2.2D", "3.2.2E", "3.2.2F", "3.2.2G", "3.2.2H", "3.3.1A", "3.3.1B", "3.3.1C", "3.3.1D", "3.3.1E", "3.3.1F", "3.3.1G", "3.3.1H", "3.3.1I", "4.1.1A", "4.1.1B", "4.1.1C", "4.1.1D", "4.1.1E", "4.1.1F", "4.1.1G", "4.1.1H", "4.1.1I", "4.1.2A", "4.1.2B", "4.1.2C", "4.1.2D", "4.1.2E", "4.1.2F", "4.1.2G", "4.1.2H", "4.1.2I", "4.2.1A", "4.2.1B", "4.2.1C", "4.2.1D", "4.2.2A", "4.2.2B", "4.2.2C", "4.2.2D", "4.2.3A", "4.2.3B", "4.2.3C", "4.2.4A", "4.2.4B", "4.2.4C", "4.2.4D", "4.2.4E", "4.2.4F", "4.2.4G", "4.2.4H", "5.1.1A", "5.1.1B", "5.1.1C", "5.1.1D", "5.1.1E", "5.1.1F", "5.1.2A", "5.1.2B", "5.1.2C", "5.1.2D", "5.1.2E", "5.1.2F", "5.1.2G", "5.1.2H", "5.1.2I", "5.1.2J", "5.1.3A", "5.1.3B", "5.1.3C", "5.1.3D", "5.1.3E", "5.1.3F", "5.2.1A", "5.2.1B", "5.2.1C", "5.2.1D", "5.2.1E", "5.2.1F", "5.2.1G", "5.2.1H", "5.2.1I", "5.2.1J", "5.2.1K", "5.3.1A", "5.3.1B", "5.3.1C", "5.3.1D", "5.3.1E", "5.3.1F", "5.3.1G", "5.3.1H", "5.3.1I", "5.3.1J", "5.3.1K", "5.3.1L", "5.3.1M", "5.3.1N", "5.3.1O", "5.4.1A", "5.4.1B", "5.4.1C", "5.4.1D", "5.4.1E", "5.4.1F", "5.4.1G", "5.4.1H", "5.4.1I", "5.4.1J", "5.4.1K", "5.4.1L", "5.4.1M", "5.4.1N", "5.5.1A", "5.5.1B", "5.5.1C", "5.5.1D", "5.5.1E", "5.5.1F", "5.5.1G", "5.5.1H", "5.5.1I", "5.5.1J", "6.1.1A", "6.1.1B", "6.1.1C", "6.1.1D", "6.1.1E", "6.1.1F", "6.1.1G", "6.1.1H", "6.1.1I", "6.2.1A", "6.2.1B", "6.2.1C", "6.2.1D", "6.2.2A", "6.2.2B", "6.2.2C", "6.2.2D", "6.2.2E", "6.2.2F", "6.2.2G", "6.2.2H", "6.2.2I", "6.2.2J", "6.2.2K", "6.3.1A", "6.3.1B", "6.3.1C", "6.3.1D", "6.3.1E", "6.3.1F", "6.3.1G", "6.3.1H", "6.3.1I", "6.3.1J", "6.3.1K", "6.3.1L", "6.3.1M", "7.1.1A", "7.1.1B", "7.1.1C", "7.1.1D", "7.1.1E", "7.1.1F", "7.1.1G", "7.1.1H", "7.1.1I", "7.1.1J", "7.1.1K", "7.1.1L", "7.1.1M", "7.1.1N", "7.1.1O", "7.1.2A", "7.1.2B", "7.1.2C", "7.1.2D", "7.1.2E", "7.1.2F", "7.1.2G", "7.2.1A", "7.2.1B", "7.2.1C", "7.2.1D", "7.2.1E", "7.2.1F", "7.2.1G", "7.3.1A", "7.3.1B", "7.3.1C", "7.3.1D", "7.3.1E", "7.3.1F", "7.3.1G", "7.3.1H", "7.3.1I", "7.3.1J", "7.3.1K", "7.3.1L", "7.3.1M", "7.3.1N", "7.3.1O", "7.3.1P", "7.3.1Q", "7.4.1A", "7.4.1B", "7.4.1C", "7.4.1D", "7.4.1E", "7.5.1A", "7.5.1B", "7.5.1C", "7.5.2A", "7.5.2B");

echo "<hr /><h2>List of all <strong>MISSING</strong> EKs</h2>";

foreach ($all_EKs as $actual_EK) {
	$covered = False;
	foreach ($all_covered_EKs as $EK) {
		if (substr_compare($EK, $actual_EK, 3, 6) == 0) {
			$covered = True;
			break;
		}
	}
	if (!$covered) {
		echo $actual_EK . "<br />";
	}
}

// define custom procedure to crawl for standards
function crawl_for_standards($input) {
	// initialize local array
	$input_url = $input[0];
	$standard = $input[1];
	global $found_standards;
	
	// dump standards on HTML pages into array
	if (substr($input_url, -4) == "html") {
		// crawl for links in HTML pages
		$html_file_lines = new simple_html_dom();
		$html_file_lines -> load_file($input_url);
		foreach($html_file_lines -> find('<li><strong>' . $standard) as $element) {
			$found_standards[$i] = $element;
		}
	}
	if (substr($input_url, -4) == "html") {
		$file_lines = file($input_url); // loads topic file into $file_lines array
		foreach ($file_lines as $i => $line) {
			if (strpos($line, '<li><strong>' . $standard)) {
				$found_standards[$i] = substr($line, strpos($line, '<li><strong>' . $standard) + 12);
			}
		}
	}
} // end function definition

?>