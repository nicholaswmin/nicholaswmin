# nix   

> [WIP]
>
> [hyper minimal][concise] blogging framwork written in Ruby,   
> inspired by Bradley Taunt's [wruby][wruby] & the [1kb club][club]
>
> `nix` means *nothing* in rejective form.


- [install](#install)
- [usage](#usage)
- [test](#test)
* [license](#license)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>


## install

It's a single-file, `nix.rb`. Download it, drop it in a folder, and:

> creates a sample blog:

```bash
# or nix -i
ruby nix.rb --init
```

> add posts as [gfm markdown][gfm] in `posts/`, and:

```bash
ruby nix.rb
```

outputs all `HTML` in `/build`.

in case you don't have [ruby][ruby]:

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
[concise]: https://en.wikipedia.org/wiki/Concision
[fswatch]: https://github.com/emcrisostomo/fswatch
[gfm]: https://github.github.com/gfm/
[id-ruby]: https://franzejr.github.io/best-ruby/idiomatic_ruby/conditional_assignment.html
[pygments]: https://pygments.org/
[file-rb]: https://github.com/nicholaswmin/nix/blob/main/nix.rb

[suckless]: https://suckless.org/philosophy/
[semantic-html]: https://html.spec.whatwg.org/multipage/#toc-dom
[aria]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA
