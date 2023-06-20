llab
====

Lightweight lab curriculum system

LLAB is a simple frame for building a course website for a sequence of activities. The goal of llab is to not be imposing, and use a simple directory structure (which you create!) to organize content. llab is mainly some Javascript wrappers and setup around basic HTML pages. It is designed to be easily deployed on any file server with no configuration.

We have an example repository in [bjc-r][bjcr]. For all comments or issues with the BJC curriculum, please see the BJC repo.

[bjcr]: https://github.com/bjc-edc/bjc-r/

## TODO - Write an Overview of How This works
* every page needs to call `llab/loader.js`;
* For optimization reasons this file needs to be adapted to each repo.

## Translations

llab now includes a translation system.
See `script/library.js` for details.

A key is added to the dictionary, and can be accessed by calling `llab.t('key')`.
`llab.translate` is also defined, but using `t` makes it easy to write code similar to the Rails i18n API.

If a key is not found in the translations dictionary, or for the requested language, then the key will be returned.
However, if a word should "disappear" in a given translation, then you can set it to the empty string.

```js
translations = {
  'key': {
    'en': 'A translation to english'
    'es': 'A translation to spanish'
  },
  'Another Phrase': {
    'de': 'Another phrase in anothe language'
  },
  'exmaple': {
    'en': 'Define replacments using %{key_name}'
  }
}
```

### Text Replacements
You may need to define text replacements in translations.
Translation values can be defined by `%{replacement_term}` in the resulting string.
You then call `llab.t(key, {replacement_term: replacement_value})` with the right terms.
Keys that cannot be replaced will be left untouched.
