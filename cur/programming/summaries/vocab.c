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
"		<title>Unit ";

char introtail[]="</title>\n"
"	</head>\n"
"\n"
"	<body>\n"
;

char outro[]="    </body>\n</html>\n";

int main(int argc, char **argv) {
    char *class=argv[1],*secp,*inp;
    char outname[100],searchstring[100],divtext[100],sect[8],entry[100];
    char unitnum[4]="0",h3[100],h2[100],units[300],link[300],link2[300];
    int fin,fout,findex,funit;
    int bflag,i,len,depth,first=1,firstpage=1,vocab=0,boxnum=0;
    char *mem,*startp,*endp,*nextp,*foop,*bazp;
    FILE *fp;
    char ch;

    unitnum[0]=argv[2][0];
    page_size = (size_t) sysconf (_SC_PAGESIZE);
    strcpy(outname, "summaries/");
    strcat(outname, class);
    strcat(outname, unitnum);
    strcat(outname, ".html");
    fp=fopen("summaries/unitnames","r");
    (void)fread(units,300,1,fp);
    (void)fclose(fp);
    if (!strcmp(argv[1],"vocab")) {
	secp=" Vocabulary";
	vocab++;
    }
    else if (!strcmp(argv[1],"exam")) secp=" On the AP Exam";
    else if (!strcmp(argv[1],"assessment-data")) secp=" Self-Check Questions";
    else secp=" Summary";
    findex=open("summaries/index-presort",O_CREAT|O_WRONLY,0744);
    (void)lseek(findex,0L,2);
    fout=creat(outname,0744);
    write(fout,intro,strlen(intro));
    write(fout,unitnum,strlen(unitnum));
    write(fout,secp,strlen(secp));
    write(fout,introtail,strlen(introtail));
    sprintf(searchstring,"<div class=\"%s",class);
    if (!strcmp(argv[1],"assessment-data")) {
	sprintf(divtext,"<div class=\"%s\" ",class);
    } else {
	sprintf(divtext,"<div class=\"%sSummary\" ",class);
    }
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
	(void)sprintf(link,"<a href=\"/bjc-r/cur/programming/%s\" title=\"/bjc-r/cur/programming/%s\">%s</a>%c",
		      argv[i],argv[i],sect,'\0');
	len=lseek(fin,0L,2);		/* get file length */
	mem=(char *)mmap(NULL,len,PROT_READ,MAP_SHARED,fin,0);
	len = ((len + page_size)/page_size)*page_size;
	if (first) {
	    first = 0;
	    foop=strchr(units,argv[2][0]);
	    endp=strchr(foop,'\n');
	    *endp='\0';
	    sprintf(h2,"<h2>%s</h2>\n%c",foop-5,'\0');
	    (void)write(fout,h2,strlen(h2));
	}
	if (!strcmp(secp-2,".1")) {	/* if first page of new lab */
	    endp=strstr(mem,"<title>");
	    foop=strstr(endp,",");
	    sprintf(h3,"<h3>%.*s</h3>\n%c",(int)(foop-(endp+14)),endp+14,'\0');
	    firstpage=1;
	} else {
	    endp=mem;
	}
	while ((startp=strstr(endp,searchstring))!=NULL) {
	    bazp = strchr(startp,' ');
	    bazp = strchr(bazp+1,' ');
	    foop = strstr(startp,">");
	    if (firstpage) {
		firstpage=0;
		(void)write(fout,h3,strlen(h3));
	    }
	    if (vocab) {
		sprintf(h2,"\n<a name=\"box%d\">\n%c",++boxnum,'\0');
		(void)write(fout,h2,strlen(h2));
	    }
	    (void)write(fout,divtext,strlen(divtext));
	    if (foop > bazp) {
		(void)write(fout,bazp,foop+1-bazp);
	    } else {
		(void)write(fout,">",1);
	    }
	    (void)write(fout,"<strong> ",9);
	    (void)write(fout,link,strlen(link));
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
	    if (vocab) {
		while (startp<endp) {
		    foop = strstr(startp,"<strong>");
		    bazp = strstr(startp,"<b>");
		    if (bazp != NULL && bazp < foop) {
			foop = bazp;
		    }
		    if (foop < endp && foop != NULL) {
			bflag = (foop[1] == 'b');
			bazp = strstr(foop, (bflag ? "</b>" : "</strong>"));
			foop = foop + (bflag ? 3 : 8);
			if (*foop == ':') foop += 2;
			if (strncmp(foop,"bi",bazp-foop) &&
				strncmp(foop,"t",bazp-foop)) {
			    (void)strncpy(entry,foop,bazp-foop);
			    entry[bazp-foop] = '\0';
			    if (strncmp(entry,"Boolean",7) && islower(entry[1])) {
				for(int j = 0; entry[j]; j++){
				    entry[j] = tolower(entry[j]);
				}
			    }
			    (void)write(findex,entry,bazp-foop);
			    (void)sprintf(link2," <a href=\"/bjc-r/cur/programming/%s#box%d\" title=\"/bjc-r/cur/programming/summaries/%s#box%d\">%s</a>\n%c",
					  outname,boxnum,outname,boxnum,sect,'\0');
			    (void)write(findex,link2,strlen(link2));
			}
			startp = bazp;
		    } else {
			startp = endp;
		    }
		}
	    }
	}
	close(fin);
	/* no more vocab boxes found in this file */
	(void)munmap(mem,len);
    }
    write(fout,outro,strlen(outro));
    close(fout);
    close(findex);
}
