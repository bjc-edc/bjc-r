# bjc-r [EDC][edc] | [Berkeley][berkeley]

[The Beauty and Joy of Computing](https://bjc.berkeley.edu) curriculum repository.

## Cloning this Repo

All content for BJC Labs lives inside this repository.

```sh
git clone git@github.com:bjc-edc/bjc-r
```

## The Awkward Forking History:

There are *two* primary `bjc-r` repositories.

* This repo ([`bjc-edc/bjc-r`][edc-gh]) contains the high school AP CSP course, Middle School, and spanish translations of curricula
* [`cs10/bjc-r`][cs10-gh] is ued primary for CS10 at UC Berkeley. [https://cs10.org/bjc-r][cs10]
* [`beautyjoy/bjc-r`][bjc-gh] is a mirror of this (bjc-edc/bjc-r) repository, just for hosting.

[edc-gh]: https://github.com/bjc-edc/bjc-r/
[cs10-gh]: https://github.com/cs10/bjc-r/
[bjc-gh]: https://github.com/beautyjoy/bjc-r/

## Viewing the Site

The public content is viewable at the following two locations:

* [https://bjc.berkeley.edu/bjc-r][berkeley]
* [https://bjc.edc.org/bjc-r][edc]

However, the repository is setup so that any fork can be run using GitHub pages.
The main BJC repo can be viewed in a live state, [here](gh), or you can use your own fork by visiting the following url: `http://[username].github.io/bjc-r/`, where you replace `[username]` with your GitHub account name.

## Running Your Own (Local) Server
While GitHub pages are convenient, you'll likely want to run your own web server
to make viewing changes much more quick and easy. Use `./run-server` — it is the
supported way to develop locally, on every platform.

```sh
./run-server
```

That's it. It opens [http://localhost:8000/bjc-r][localhost] in your browser, and
Control-C stops it. The only requirement is Python 3; on Windows, run it from
PowerShell or WSL.

The server mirrors the URL layout of the real site, so absolute links like
`/bjc-r/img/...` resolve exactly as they do in production.

Caching is disabled for the files you actually edit — `.html`, `.css`, `.js`,
`.topic`, and `.xml`, the same set `.htaccess` marks no-cache in production — so
a reload always shows the file you just saved and you should never need a hard
refresh. Images and other assets cache normally, which keeps page loads fast.

| Command | What it does |
| --- | --- |
| `./run-server` | Serve over http on port 8000 |
| `./run-server 9000` | Use a different port |
| `./run-server --https` | Serve over https (see below) |
| `./run-server --no-open` | Don't open a browser window |
| `./run-server --make-cert` | Replace the https certificate |
| `./run-server --help` | List every option |

If the port is already in use, the server says so and tells you how to find what
is holding it (`lsof -i tcp:8000`).

### Serving over https

A few things — service workers, some clipboard and media APIs — only work on a
secure origin. `./run-server --https` covers those cases:

```sh
./run-server --https
```

The first run generates a self-signed certificate for `localhost` in
`utilities/certs/` (gitignored). It is good for 30 days and is regenerated
automatically once it is within a week of expiring, so it can never silently go
stale. To replace it at any time, run `./run-server --make-cert`.

Because the certificate signs itself, your browser will warn you the first time.
Click through it, or teach macOS to trust it once:

```sh
security add-trusted-cert -r trustRoot -k ~/Library/Keychains/login.keychain-db utilities/certs/localhost.pem
```

(You'll need to re-run that after each regeneration. If you'd rather not, a tool
like [mkcert](https://github.com/FiloSottile/mkcert) can install a local CA once
and issue certificates your browser trusts without a prompt.)

## Contributing

### [Review the Contributing and Authorship Guide][contributing].

However, for the most part, all you need to do is write some HTML.
To contribute:
1. Create your own fork of `bjc-r`.
2. Create a new branch for your feature.
3. Work away!
4. Create a pull request.
5. Get feedback on the pull request and make changes as needed.
6. Be super awesome! :)

Of course, submitting issues is always welcome and encouraged! These issues can be bugs, questions, improvements or anything you'd like to share.

## Index and Summary Pages

See `utilities/build-tools/README.md` for information on how to build the index and summary pages.

```sh
bundle exec ruby utilities/build-tools/rebuild-all.rb
```

## UC Berkeley Deployment Process

@beautyjoy/bjc-r serves bjc.berkeley.edu/bjc-r from the `main` branch.

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
