#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <sys/mman.h>
#include <regex.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

size_t page_size;

char intro[]="<!DOCTYPE html>\n"
"<html lang=\"en\">\n"
"	<head>\n"
"		<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />\n"
"		<script type=\"text/javascript\" src=\"/bjc-r/llab/loader.js\"></script>\n"
"		<script type=\"text/javascript\" src=\"/bjc-r/utilities/gifffer.min.js\"></script>\n"
"        <script type=\"text/javascript\">window.onload = function() {Gifffer();}</script>\n"
"        <link rel=\"stylesheet\" type=\"text/css\" href=\"/bjc-r/css/bjc-gifffer.css\">\n"
"		<title>Index</title>\n"
"	</head>\n"
"\n"
"	<body>\n<ul>\n"
;

char outro[]="</li></ul>\n    </body>\n</html>\n";

int main(int argc, char **argv) {
    FILE *fin,*fout;
    char line[1000], old[1000];
    char *page;

    fin=fopen("index-sorted","r");
    fout=fopen("vocab-index.html","w");

    fprintf(fout,"%s",intro);
    old[0] = '\0';

    while (fgets(line,1000,fin) != NULL) {
	page = strstr(line, "<a ");
	if (strncmp(line, old, page-line)) {
	    fprintf(fout,"</li>\n<li>%s",line);
	    strncpy(old, line, page-line);
	    old[page-line] = '\0';
	} else {
	    fprintf(fout,",&nbsp; %s",page);
	}
    }
    fprintf(fout,"%s",outro);
    fclose(fin);
    fclose(fout);
}
