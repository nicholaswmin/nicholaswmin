# pop

> a microblogging framework written in Ruby, 
> heavily adapted by [wruby][wruby]

## blogging

Posts go under `posts/` folder as `.md` files.  

They must have an:

- `h1` on the first line, 
- a `space` on the second
- the `date` on the 3rd, ie. `2024-10-18`.

additionally:

- media (images/video) to folder
- css in `public/style.css`

## install

```bash
brew install ruby
```
> my ruby is: v3.3.5

then download the file 

## build & serve

just run:

```bash
make build
```

which output everything in `build/` folder.

### Watch files & build, serve

Grab:

```bash
brew install fswatch
```

then run:

```js
fswatch -o -r -d ./ -e build | xargs -n1 -I{} make build & ruby -run -e httpd -- build
```


built with [wruby][wruby]


[club]: https://1kb.club/
[wruby]: https://git.btxx.org/wruby/about/
