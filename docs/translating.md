# Translating BJC

This is a guide for translating BJC content into another language.

## Overview:

Every object (a page, image, XML file) could potentially have a translated counterpart. We store all translations _alongside_ the English translation of the file. The translated files will all the same file name, but use the language code as part of the extension. For example, `hello.html` translated to Spanish would belong in a file `hello.es.html`.

There current exists a work-in-progress Spanish translation of the CSP curricula.

For example, consider the first part of Lab 1, which is "Building an App". The content lives inside `cur/programming/1-introduction/1-building-an-app/`

This directory has the following files:
```sh
$ ls -l cur/programming/1-introduction/1-building-an-app/
-rw-r--r--@ 1 Michael  staff   2897 Sep  7  2021 1-creating-a-snap-account.html
-rw-r--r--@ 1 Michael  staff  10699 Sep  7  2021 2-start-your-first-snap-app.html
-rw-r--r--@ 1 Michael  staff   6686 Sep  7  2021 3-loading-mobile-device.html
-rw-r--r--@ 1 Michael  staff   6424 Sep  7  2021 4-keeping-score.html
-rw-r--r--@ 1 Michael  staff   3116 Sep  7  2021 5-finish-your-first-snap-app.html
drwxr-xr-x@ 6 Michael  staff    192 Oct 13 15:44 old
```

In each of this folders we should maintain the same directory structure and filenames. **Filenames should not be translated.**

## Translating Images: TODO

* Make sure to use smart pics
* Update the English pics
* export translated pics
* save block translations, and update both english and spanish XMLs
