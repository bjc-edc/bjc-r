<?php 

// Written by Mary Fries, Oct 3-11, 2017
// See also: http://php.net/manual/en/function.imagecolorat.php

// initialize variable to hold image
$png = "../img/6-computers/bjcfav_small.png";
echo "<h2>Color version: " . $png . "</h2>";
$im = imagecreatefrompng($png);


// initialize array to store colors
$color_array = array();

// define funciton to make color values 3-digits
function pack8bitbyte($string) {
	while (strlen($string) < 8) {
		$string = "0" . $string;
	}
	return $string;
}

// loop through columns (color version)
for($y = 0; $y < imagesy($im); $y++) {
	// initailize or re-initailize array to store row of colors
	$row_array = array();
	// loop through rows
	for($x = 0; $x < imagesx($im); $x++) {
		// get RGB value for pixel
		$rgb = imagecolorat($im, $x, $y);
		// separate R, G, and B
		$r = ($rgb >> 16) & 0xFF;
		$g = ($rgb >> 8) & 0xFF;
		$b = $rgb & 0xFF;
		// load RGB array into row array
		array_push($row_array, array($r, $g, $b));
	}
	// load row arraway into color array
	array_push($color_array, $row_array);
}



// Now display the resulting binary sequence:
// loop through columns
for($y = 0; $y < imagesy($im); $y++) {
	// loop through rows
	for($x = 0; $x < imagesx($im); $x++) {
		// loop through colors
		for($n = 0; $n <= 2; $n++) {
			// display each pixel component in binary
			echo pack8bitbyte(decbin($color_array [$y][$x][$n]));
		}
	}
}


// initialize variable to hold image
$pngbw = "../img/6-computers/bjcfav_small_bw.png";
echo "<h2>B&W version: " . $pngbw . "</h2>";
$imbw = imagecreatefrompng($pngbw);

// initialize array to store B&W values
$bw_array = array();

// loop through columns (B&W version)
for($y = 0; $y < imagesy($imbw); $y++) {
	// initailize or re-initailize array to store row of colors
	$row_array = array();
	// loop through rows
	for($x = 0; $x < imagesx($imbw); $x++) {
		// get RGB value for pixel
		$rgb = imagecolorat($imbw, $x, $y);
		if ($rgb == 16777215) {
			// if black, load "0" into row array
			array_push($row_array, 0);
		}
		else {
			// otherwise (should be white), load "1" into row array
			array_push($row_array, 1);
		}
	}
	// load row arraway into color array
	array_push($bw_array, $row_array);
}

// Now display the resulting binary sequence:
// loop through columns
for($y = 0; $y < imagesy($imbw); $y++) {
	// loop through rows
	for($x = 0; $x < imagesx($imbw); $x++) {
		// display each pixel component
		echo $bw_array [$y][$x];
	}
}
?>