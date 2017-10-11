<?php 

// Written by Mary Fries, Oct 3, 2017
// See also: http://php.net/manual/en/function.imagecolorat.php

// initailize variable to hold image
$im = imagecreatefrompng("../img/6-computers/bjcfav_small.png");

// initailize array to store colors
$color_array = array();

// define funciton to make color values 3-digits
function pack8bitbyte($string) {
	while (strlen($string) < 8) {
		$string = "0" . $string;
	}
	return $string;
}

// loop through columns
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


$count = 0;

// Now display the resulting binary sequence:
// loop through columns
for($y = 0; $y < imagesy($im); $y++) {
	// loop through rows
	for($x = 0; $x < imagesx($im); $x++) {
		// loop through colors
		for($n = 0; $n <= 2; $n++) {
			// display each pixel component in binary
			echo pack8bitbyte(decbin($color_array [$y][$x][$n]));
			$count += 8;
		}
	}
}
echo "<br />" . $count;

echo "<br /><br />fourth row:<br />";

for($x = 0; $x < imagesx($im); $x++) {
	for($n = 0; $n <= 2; $n++) {
		echo $color_array [4][$x][$n] . " ";
	}
	echo "<br />";
}
echo "<br /><br />fourth row:<br />";

for($x = 0; $x < imagesx($im); $x++) {
	for($n = 0; $n <= 2; $n++) {
		echo pack8bitbyte(decbin($color_array [4][$x][$n])) . " ";
	}
	echo "<br />";
}

?>