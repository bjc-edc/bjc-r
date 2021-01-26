#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <sys/mman.h>
#include <regex.h>
#include <stdio.h>

size_t page_size;

char intro[]="<!DOCTYPE html>\n"
"<html lang=\"en\">\n"
"	<head>\n"
"		<meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />\n"
"		<script type=\"text/javascript\" src=\"/bjc-r/llab/loader.js\"></script>\n"
"		<script type=\"text/javascript\" src=\"/bjc-r/utilities/gifffer.min.js\"></script>\n"
"        <script type=\"text/javascript\">window.onload = function() {Gifffer();}</script>\n"
"        <link rel=\"stylesheet\" type=\"text/css\" href=\"/bjc-r/css/bjc-gifffer.css\">\n"
"		<title>Glossary</title>\n"
"	</head>\n"
"\n"
"	<body>\n"
;

char outro[]="    </body>\n</html>\n";

int main(int argc, char **argv) {
    char *class=argv[1],*secp,*inp;
    char outname[100],sect[8];
    int fin,fout,i,len,depth;
    char *mem,*startp,*endp,*nextp,*foop;
    char ch;

    page_size = (size_t) sysconf (_SC_PAGESIZE);
    strcpy(outname, class);
    strcat(outname, ".html");
    fout=creat(outname,0744);
    write(fout,intro,strlen(intro));
    for (i=2;i<argc;i++) {		/* for each input file */
	fin=open(argv[i],O_RDONLY);
	secp=sect;
	*secp++ = argv[i][0];		/* sect <- "u.l.p" from filename */
	inp = argv[i];
	while ((ch=*inp++) != '\0') {
	    if (ch == '/') {
		*secp++ = '.';
		while (isdigit(*inp)) {
		    *secp++ = *inp++;
		}
	    }
	}
	*secp = '\0';
	len=lseek(fin,0L,2);		/* get file length */
	mem=(char *)mmap(NULL,len,PROT_READ,MAP_SHARED,fin,0);
	len = ((len + page_size)/page_size)*page_size;
	endp=mem;
	while ((startp=strstr(endp,"<div class=\"vocab"))!=NULL) {
	    foop = strstr(startp,">");
	    (void)write(fout,"<div class=\"vocabFullWidth\"><strong> ",37);
	    (void)write(fout,sect,strlen(sect));
	    (void)write(fout,"</strong>",9);
	    startp = foop+1;
	    depth=1;
	    endp=nextp=startp;
	    while (depth) {
		endp=strstr(nextp,"</div");
		if ((foop=strstr(nextp,"<div"))!=NULL && foop < endp) {
		    endp=foop;
		}
		if ((*(++endp)) == '/') {
		    --depth;
		    endp++;
		} else if ((*endp) == 'd') {
		    depth++;
		}
		nextp=endp;
	    }
	    endp += 4;	    /* for the "div>" */
	    (void)write(fout,startp,endp-startp);
	    (void)write(fout,"\n",1);
	}
	close(fin);
	/* no more vocab boxes found in this file */
	(void)munmap(mem,len);
    }
    write(fout,outro,strlen(outro));
    close(fout);
}
