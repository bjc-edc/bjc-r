# bjc-r

The Beauty and Joy of Computing labs repository.

## Cloning this Repo

All content for BJC Labs lives inside this repository.

```sh
git clone git@github.com:bjc-edc/bjc-r
```

## The Awkward Forking History:

There are *two* primary `bjc-r` repositories.

* This repo (`bjc-edc/bjc-r`) contains the high school AP CSP course, Middle School, and spanish translations of curricula
* `cs10/bjc-r` is ued primary for CS10 at UC Berkeley. [https://cs10.org/bjc-r][cs10]
* `beautyjoy/bjc-r` currently does not exist, but will become a mirror of the bjc-edc/bjc-r repository.

## Viewing the Site

This repo lives on the following two domains:

* [https://bjc.berkeley.edu/bjc-r][berkeley]
* [https://bjc.edc.org/bjc-r][edc]

However, the repository is setup so that any fork can be run using GitHub pages.
The main BJC repo can be viewed in a live state, [here](gh), or you can use your own fork by visiting the following url: `http://[username].github.io/bjc-r/`, where you replace `[username]` with your GitHub account name.

## Running Your Own (Local) Server
While GitHub pages are convenient, you'll likely want to run your own web server
to make viewing changes much more quick and easy. In order to view the labs, you'll need to have an Apache server running on your machine. Here are some simple instructions for a couple different platforms.

__No matter the platform, you should server files from `/bjc-r/` at the root of your server.__

### macOS and Unix
The easiest way to setup a server is to use a simple, built-in Python server.
1. `cd` into one level above the `bjc-r` directory.
2. In a separate window run `python -m SimpleHTTPServer` (for Python 2) or `python3 -m http.server` for Python 3.
3. Navigate to [http://localhost:8000/bjc-r][localhost] in a browser.
4. That's it! :)

### Windows
Windows guide coming...sometime. However, the Python solution should work as well, provided you install Python.

## Contributing

### [Review the Contributing and Authorship Guide][contributing].

However, for the most part, all you need to do is write some HTML.
To contribute:
1. Create your own fork of `bjc-r`.
2. Optionally: Create a new branch for your feature.
3. Work away!
4. Create a pull request.
5. Get feedback on the pull request and make changes as needed.
6. Be super awesome! :)

Of course, submitting issues is always welcome and encouraged! These issues can be bugs, questions, improvements or anything you'd like to share.

## UC Berkeley Deployment Process (March 2022)

The repo's `master` branch should always be in a directly deployable state. The files can be put on a web server inside a folder served at `/bjc-r` without modification. Each time we want to deploy the curriculum, we create a [Release](https://github.com/bjc-edc/bjc-r/releases). (Releases show in git as a tag when you check out the code.)

1. ssh into user@abbenay.cs.berkeley.edu
2. Your home directory should be `~/bjc` (`/home/bh/public_html/bjc/`
3. `cd bjc-r`
4. `git fetch`
5. Look at the latest releases, should be at the bottom of the output.
6. `git checkout [tag name]`, e.g. `git checkoutout 2022-03-15`

## License
[CC-BY-NC-SA 3.0][cc]

![CC_IMG][cc_img]

<!-- Links for the doc -->
[contributing]: docs/README.md
[cc]: https://creativecommons.org/licenses/by-nc-sa/3.0/
[cc_img]: https://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png
[cs10]: https://cs10.org/bjc-r
[localhost]: http://localhost:8000/bjc-r
[berkeley]: https://bjc.berkeley.edu/bjc-r/
[edc]: https://bjc.edc.org/bjc-r
