# nix   

> [WIP]
>
> a [hyper minimal][concise] blogging framwork written in Ruby.
> 
> inspired by Bradley Taunt's [wruby][wruby] & the [1kb club][club]
>
> `nix` means *nothing* in rejective form.


## install

It's just a single-file, `nix.rb`. You just need [ruby][ruby].

> in case you don't have it:

```bash
brew install ruby
```

Download `nix.rb`, drop it in a folder, and:

> generate a sample blog

```bash
# or nix -i
nix --init
```

## usage 

It's like [Jekyll][jekyll]. You write [Github-flavored Markdown][gfm]

- Add posts in `posts/`
- Add pages in `pages/`

They *must* have an:

- `# <post-title>` on the 1st line
- `empty line` on the 2nd
- `<date>` on the 3rd, ie. `2024-10-18`

Example post (or page):

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

- add any media (images/video) in `public/`.
- css styles are in `public/style.css`
- site options are in `_config.rb`

## build

just run:

```bash
ruby nix.rb
```

outputs all in `build/`.

### Rebuild on file change

> Tired of pressing `save` on every change?

Grab [`fswatch`][fswatch]:

```bash
brew install fswatch
```

then run:

```js
fswatch -o -r -d ./ -e build | xargs -n1 -I{} make build & ruby -run -e httpd -- build
```

Written for testability, in [*idiomatic Ruby*][id-ruby].

## Conventions

- Produces [Semantic HTML][semantic-html] & the [ARIA specs][aria]
- Designed for testability, written in [*idiomatic Ruby*][id-ruby].
- Follows a [suckless philosophy][suckless]

## License

[The MIT License](https://spdx.org/licenses/MIT)

[club]: https://1kb.club/
[ruby]: https://ruby-doc.org/3.3.4/
[wruby]: https://git.btxx.org/wruby/about/
[jekyll]: https://jekyllrb.com/
[concise]: https://en.wikipedia.org/wiki/Concision
[fswatch]: https://github.com/emcrisostomo/fswatch
[gfm]: https://github.github.com/gfm/
[id-ruby]: https://franzejr.github.io/best-ruby/idiomatic_ruby/conditional_assignment.html

[suckless]: https://suckless.org/philosophy/
[semantic-html]: https://html.spec.whatwg.org/multipage/#toc-dom
[aria]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA
