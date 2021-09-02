# bjc-r utilites

## Pandoc Conversion

**Single File**

```
pandoc --from html --to docx --lua-filter=utilities/remove-todos.lua -o test.docx cur/programming/1-introduction/2-gossip-and-greet/1-pair-programming.html
```
