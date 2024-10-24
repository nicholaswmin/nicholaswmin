# nix   

> [WIP]
>
> [hyper minimal][concise] blogging framework written in Ruby,   
> inspired by Bradley Taunt's [wruby][wruby] & the [1kb club][club]
>
> `nix` means *nothing* in rejective form.


- [install](#install)
- [init](#usage)
- [blog](#usage)
- [publish](#usage)
- [test](#test)
- [license](#license)

## install

It's a single-file, [nix.rb][file-rb]; download & drop it in a folder:


## init

> create a sample blog:

```bash
ruby nix.rb --init
```

## blog

add [markdown][gfm] in `posts/`, then:

> build HTML in `build/`:

```bash
ruby nix.rb
```

outputs all `HTML` in `/build`.

## publish

>  via [Github Pages][gh-pages]: 

`git push` all changes 

- Visit `Repository` > `Settings` > `Pages`
- Click `Enable` on branch `main` and folder `build/`

visit: `<username>.github.io/<repo>`

```bash
brew install ruby
```

## usage 

It's like [Jekyll][jekyll]. You write [Github-flavored Markdown][gfm].

> inc. syntax highlighting for 150 languages via [`pygments`][pygments]

- Add posts in `posts/`
- Add pages in `pages/`

 ... each *must* have an:

- `# <post-title>` on the 1st line
- `empty line` on the 2nd
- `<date>` on the 3rd, ie. `2024-10-18`

... an example:

```markdown
# Lorem Ipsum

2024-12-20

A sentence should contain no unnecessary words, a paragraph no unnecessary 
sentences, for the same reason that a drawing should have no unnecessary lines 
and a machine no unnecessary parts. This requires not that the writer make all 
his sentences short, or that he avoid all detail and treat his subjects only 
in outline, but that every word tell

The Elements of Style by William Strunk Jr (1918) ...
```

additionally:

- images go in `public/`.
- css are in `public/style.css`
- config site via `_config.rb`

## Rebuild on file change

> tired of pressing `save` on every change?

Grab [`fswatch`][fswatch]:

```bash
brew install fswatch
```

then run:

```js
fswatch -o -r -d ./ -e build | xargs -n1 -I{} make build & ruby -run -e httpd -- build
```

## test

```bash
@todo
```

## conventions

- follows [Semantic HTML][semantic-html] & the [ARIA specs][aria]
- designed for testability, written in [*idiomatic Ruby*][id-ruby].
- [suckless philosophy][suckless]

## license

[The MIT License](https://spdx.org/licenses/MIT)

[club]: https://1kb.club/
[ruby]: https://ruby-doc.org/3.3.4/
[wruby]: https://git.btxx.org/wruby/about/
[jekyll]: https://jekyllrb.com/
[gh-pages]: https://pages.github.com/
[concise]: https://en.wikipedia.org/wiki/Concision
[fswatch]: https://github.com/emcrisostomo/fswatch
[gfm]: https://github.github.com/gfm/
[id-ruby]: https://franzejr.github.io/best-ruby/index.html
[pygments]: https://pygments.org/
[file-rb]: https://github.com/nicholaswmin/nix/blob/main/nix.rb

[suckless]: https://suckless.org/philosophy/
[semantic-html]: https://html.spec.whatwg.org/multipage/#toc-dom
[aria]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA
