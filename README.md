> is a single-file static-site generator in 150 lines of [ruby][ruby]

> although nix is fully-working framework, it was written as a proof-of-concept
> 
> It's distinguishing characteristic is that it's archicture & system design philosophy  
> (over)emphasizes [simplicity][kiss] to an unsual degree;
> even more that [program correctness][corr]
>
> Read more:
> - [The New Jersey style/Worse is Better][njs] by Richard Gabrielle, MIT
> - [Locality of Behaviour][lob]: Carson Gross
>
> It aims to balance 3 competing requirements:
> 
> - it must be extemely easy to make sense of
> - it must actually allow publishing a site
> - it must be extremely easy to setup
> - it must be extemely easy to make sense of
> - it must follow conventions to a certain degree
>
> ## todo
> - [ ] tests
> - [ ] cleanup
> - [ ] docs

Instead of installing `X`/`Y`  publishing framework on your system,   
it inverts the process by embedding the "framework" in the site itself.

- create a repo & drop `nix.rb` into it
- run `nix.rb --init`
- add posts & pages as [markdown][gfm]
- `git push`

... which publishes automatically on [Github Pages][gh-pages].

### todo 
- [ ] unit tests
- [ ] data should be pruned outside of this readme
- [ ] code docs

anyone with repository access can edit/publish the site by simply cloning the repo,  
add/edit posts and re-pushing to `main`.

```bash
Usage: nix [options]

nix  --init            create sample blog
nix  --build           build static HTML
nix  --watch           rebuild on file change
```

## todo

- [ ] docs
- [ ] unit tests

## Publish a site

1. create a Github repo with enabled pages.
2. drop the [nix.rb](#get-nix) file in it.
3. Run `ruby nix.rb --init` to generate a sample site
5. push to `main` branch

... which publishes a barebones site consistent with the [1kb philosophy](https://1kb.club/) at: `<user>.github.io/<repo>`

### Publish new content


1. write markdown in `posts/` and `pages/`
2. push to `main` branch


## quick start 

Say you have a repo with the following structure:


`repo`  
┣━`nix.rb`  
┗━`README.md`


> generate a minimal sample blog:

```bash
ruby nix.rb --init
```

## write posts

- add [markdown][gfm] posts in `/posts`
- add [markdown][gfm] pages in `/pages`
- add images, videos, CSS in `/public`

posts include [syntax highlighting][rouge], 
just wrap them in code fences (\`\`\`) as usual:

```js
const hello = 'world'
```

moving on..

> build to static HTML, at `/build`

```bash
ruby nix.rb --build
# build ok!
```

or even better:

> rebuild automatically on file change

```bash
ruby nix.rb --watch
```

## publish it

Just push to `main`. 

An autogenerated Github workflow will run `nix --build` to compile   
everything once-more & deploy at: https://username.github.io/repo-name.

> `/build` directory is recompiled on `push` so you can safely `.gitignore`
> it entirely.

## post format

just make sure each page or post has:

- an `h1` title on the 1st line
- an `empty line` on the 2nd line
- a `<date>` on the 3rd, ie. `2024-10-18`

the rest is up to you.

> example:

```markdown
# Some pretentious post title
 
2024-12-20

> A sentence should contain no unnecessary words, a paragraph no unnecessary 
> sentences, for the same reason that a drawing should have no unnecessary lines 
> and a machine no unnecessary parts. This requires not that the writer make all 
> his sentences short, or that he avoid all detail and treat his subjects only 
> in outline, but that every word tell

The Elements of Style by William Strunk Jr (1918) ...
``` 

### get nix

`nix` is just a single-file; it's max 150 lines of code & it includes everything 
necessary to develop and publish a [ridicously minimal][club] yet functional 
blog site. 

grab it from this repo [directly][download], or just `curl` it:

```bash
curl -O https://raw.githubusercontent.com/nicholaswmin/nix/main/nix.rb
```

apart from [Ruby 3.3][ruby] there's nothing to install; 
nor any commands to run. You don't need to run `gem install`. 
It's not available as a `gem` either; 

This is [intentional](#wheres-the-rest-of-it)

## Quirks

### Asset paths

Don't use absolute paths to reference assets.   

Github Pages has a well-known quirk of serving from a non-root path,
applicable to all static-site generators.

this won't work:

```html
<img src="/public/felix.svg"></img>
<img src="/felix.svg"></img>
```

use relative paths instead:

```html
<img src="../../felix.svg"></img>
```

even better, use `{{root_url)}`:

```html
<img src="{{root_path}}/felix.svg"></img>
<!-- auto expands to <img src="../../felix.svg"></img> -->
```

it's rewritten automatically & resolves to the correct root regardless of the   
page position, so it's less error-prone than manually writing relative paths.

> same in markdown:

```md
[1]: {{root_url}}felix.svg
```

### root resolution in ruby

> in case you're extending `nix`:

`root_url` is also available as a method 
which has the same effect:

```ruby
root_url('felix.svg')
# ../../felix.svg
```

more context:

```ruby
class CustomPage < HTMLPage
  # omitted ...

  def render(ctx)
    super + 
      "<link rel=\"stylesheet\" href=\"#{root_url('highlight.css')}\"><link>"
  end
end
```

## Wheres the rest of it?

> This project is actually part of a weekly workshop I was invited to do
> in an SME. It's an actual project that you can use but it's primary purpose
> was illustrative.

The idea behind it closely mimics [wruby](https://wruby.passthejoe.net/about/),
a static-site generator that generates [sites that are under 1kb][club].

While the whole thing looks more like a code-golfing joke than anything 
substantial, it's philosophy is based around serious ideas that emerged 
in MIT and Berkley around the 80s(?), regarding software architecture design. 

Despite their similarities, under the hood `wruby` is written entirely
procedurally. 

There is a clear *lack* of architecture and you can more or less describe it
as a cooking recipe.

What I've done is take wruby and rewrite it's core ideas in 
an [Object-Oriented paradigm][oop]; in an effort to make the code more 
"modern" and "extensible"; in effect I've proved the entire point of the 
argument, the tendency to introduce unnecessary complexity on our own.

`nix` is using a lot of ideas supposedly considered "Best Practices".
Data is moved around in a functional manner; the API is implemented in a fluent
prose with clear hierarchical organisation into classes/types. 

Additionally, there's a clear and intentional Separation of Concerns between 
persistence code and logic code; the purpose of this is to make it amerable to 
unit-testing.

`wruby` has **absolutely none** of the above.  

it's really just a bunch of functions glued together.   
It's not possible to extend it without pulling out your hair *but* nor is
there any indication that it's purpose was to be extensible.

wruby is actually one of the few projects that I sat through 
reading it's entire source-code without getting bored or distracted, 
because it is just *that* simple.

Both projects are written in Ruby.

Both projects are based on material from the following essays:

- [Worse is Better][worse-is-better], [Richard P. Gabriel][rpg]
- [Is Worse Really Better?][worse-better], Richard P. Gabriel
- [Locality of Behavior][loc], Carson Gross
- [Chesterson's Fence: A lesson in thinking][chest-fence]

From the Unix-Haters handbook    
[Simson Garfinkel](https://en.wikipedia.org/wiki/Simson_Garfinkel)

> [...] Literature that Unix succeeded because of its technical superiority. 
> This is not true. Unix was evolutionarily superior to its competitors, 
> but not technically superior. Unix became a commercial success because 
> it was a virus. 
> Its sole evolutionary advantage was its small size, simple design, and 
> resulting portability.

> ### From [Worse is Better vs The Right Thing][worse-is-better]  
>
> The New Jersey style of software architecture design    
> vs the MIT/Stanford approach   
>
> [Richard P. Gabriel][rpg], 1991  
>
> [... ] I and just about every designer of Common Lisp and CLOS has
> had extreme exposure to the MIT/Stanford style of design. 
> The essence of this style can be captured by the phrase *The Right Thing*. 
> To such a designer it is important to get all of the following characteristics 
> right:
>
> #### Simplicity
> the design must be simple, both in implementation and interface. 
> It is more important for the interface to be simple than the implementation.
>
> #### Correctness 
> The design must be correct in all observable aspects. Incorrectness is simply 
> not allowed.
>
> #### Consistency
> The design must not be inconsistent. 
> A design is allowed to be slightly less simple and less complete to avoid 
> inconsistency. Consistency is as important as correctness.
>
> #### Completeness
> The design must cover as many important situations as is 
> practical. All reasonably expected cases must be covered. 
> Simplicity is not allowed to overly reduce completeness.
>
----
> 
> [...] The **Worse is Better** philosophy is only slightly different:
>
> #### Simplicity
> The design must be simple, both in implementation and interface.  
> It is more important for the implementation to be simple than the interface. 
> Simplicity is the most important consideration in a design.
>
> #### Correctness 
> The design must be correct in all observable aspects. 
> It is slightly better to be simple than correct.
>
> #### Consistency
> The design must not be overly inconsistent.   
> Consistency can be sacrificed for simplicity in some cases, 
> but it is better to drop those parts of the design that deal with 
> less common circumstances than to introduce either implementational 
> complexity or inconsistency.nt as correctness.
>
> #### Completeness
> Completeness -- the design must cover as many important situations as is 
> practical. All reasonably expected cases should be covered. Completeness 
> can be sacrificed in favor of any other quality. In fact, compzleteness must 
> be sacrificed whenever implementation simplicity is jeopardized. 
> Consistency can be sacrificed to achieve completeness if simplicity is 
> retained; especially worthless is consistency of interface. 
>
> I have intentionally caricatured the worse-is-better philosophy to convince 
> you that it is obviously a bad philosophy and that the New Jersey approach 
> is a bad approach.
>
> [...] However, I believe that worse-is-better, even in its strawman form, has 
> better survival characteristics than the-right-thing, and that 
> the New Jersey approach when used for software is a better approach 
> than the MIT approach[...]


[nix]: https://github/com/nicholaswmin/nix
[club]: https://1kb.club/
[ruby]: https://franzejr.github.io/best-ruby/
[jekyll]: https://jekyllrb.com/
[gh-pages]: https://pages.github.com/
[gh-actions]: https://github.com/features/actions
[gfm]: https://github.github.com/gfm/
[rouge]: https://github.com/rouge-ruby/rouge
[pygments]: https://pygments.org/
[file-rb]: https://github.com/nicholaswmin/nix/blob/main/nix.rb
[fi-join]: https://ruby-doc.org/3.3.2/File.html#method-c-join
[ruby]: https://ruby-doc.org/3.3.5/
[download]: https://github.com/nicholaswmin/nix/blob/main/nix.rb
[kiss]: https://en.wikipedia.org/wiki/KISS_principle#In_software_development
[corr]: https://en.wikipedia.org/wiki/Correctness_(computer_science)
[oop]: https://en.wikipedia.org/wiki/Object-oriented_programming
[njs]: https://en.wikipedia.org/wiki/Worse_is_better
[lob]: https://htmx.org/essays/locality-of-behaviour
[worse-better]: https://dreamsongs.com/Files/IsWorseReallyBetter.pdf
[worse-is-better]: https://curtsinger.cs.grinnell.edu/teaching/2021S1/CSC213/files/worse_is_better.pdf
[rpg]: https://en.wikipedia.org/wiki/Richard_P._Gabriel
[chest-fence]: https://fs.blog/chestertons-fence/
[polymor]: https://en.wikipedia.org/wiki/Subtyping
[encapsu]: https://en.wikipedia.org/wiki/Encapsulation_(computer_programming)
<!---d
---
# This YAML embed contains the necessary data 
# to create a sample blog site.
# 
# When the `--init` flag is passed, it: 
#
# - searches for this file locally, in the current working directory.
# - if not found, it attempts to download it from the repo. (raw)
# - It then iterates through the keys and creates a file for each.
# - each key is a filename. The file contents are listed under each key.

- _config.yml: |
    # Site configuration
    # note: these key/values can also be used as substitutions.
    # i.e: {{author_name}} in a Post will be replaced with "John Doe"

    # required
    name: 'John Does blog'
    description: 'a blog about rabbits'
    favicon: 🧸
    # must match static.yml workflow value:
    dest: './build'

    # optional

    author_name: 'John Doe'
    author_user: 'nicholaswmin'
    author_city: 'London, W2'


- .github/workflows/static.yml: |
    name: Deploy static HTML to Pages
    
    on:
      push:
        branches: [$default-branch, 'refactor-b']
    
      # allow manual runs from the Actions tab
      workflow_dispatch:
    
    permissions:
      contents: read
      pages: write
      id-token: write
    
    concurrency:
      group: "pages"
      cancel-in-progress: false
    
    jobs:
      deploy:
        environment:
          name: github-pages
          url: ${{ steps.deployment.outputs.page_url }}
        runs-on: ubuntu-latest
        steps:
          - name: Checkout
            uses: actions/checkout@v4
    
          - name: Setup Ruby 3.3.5
            uses: ruby/setup-ruby@v1
            with:
              ruby-version: '3.3.5'

          - name: Setup Pages
            uses: actions/configure-pages@v5
    
          - name: Fetch init site assets
            run: ruby nix.rb -i
            
          - name: Compile Pages
            run: ruby nix.rb -b
    
          - name: Upload artifact
            uses: actions/upload-pages-artifact@v3
            with:
              # must match value of `_config.yml`:`dest`
              path: './build'
          - name: Deploy to GitHub Pages
            id: deployment
            uses: actions/deploy-pages@v4

- _layouts/header.html: |
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="{{description}}">
        <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'><text x='0' y='14'>{{favicon}}</text></svg>">
        <link rel="stylesheet" href="{{root_url}}style.css">
        <title>{{title}}</title>
    </head> 

    <nav>
        <ul>
        <li><a href="{{root_url}}">posts</a></li>
        <li><a href="{{root_url}}about">cv</a></li>
        </ul>
    </nav>

- _layouts/footer.html: |
    <footer>
        <small> > <a href="https://1kb.club/">{{bytes}} bytes</a> </small>
    </footer>

- pages/index.md: |
    hello world

- pages/about.md: |
    cv

    {{author_name}}
    [{{author_user}}][author-url]
    {{author_city}}

    - ACME Industries
      - 2015 - now  
      - London, United Kingdom

    - Foo/Bar GmbH
      - Dec 22' - May 23'
      - Munich, Germany

    - Ski Instructor
        - Dec 22' - May 23'
        - Rhône-Alpes, France

    - Looney Tunes LLC
      - Dec 16' - Nov 20'
      - Madrid, Spain

    - The Animaniacs LLC
      - Jun 14' - Apr 15'
      - New York, USA  

    #### Schools

    - University of Westminster
      - BSc Information Systems
      - London, UK  
      - 2009 - 2013

    [author-url]: https://github.com/{{author_user}}

- pages/sample.md: |
    ## sample

    This is a sample `Page`; i.e: not a `Post`.   

    It's is written in `Markdown` but doesn't support    
    code syntax highlighting nor is it included in any Post lists.   

    You can add as many as you want within this folder.    
    Just like a `Post`, it requires an `h2` header at the top.

- posts/whats-this.md: |
    # whats this?

    21-10-2021

    This is a sample post, written in [github-flavored markdown][gfm].

    It's generated using a minimal static-site generator, 
    called [nix][nix], which itself is ~150 lines of [ruby][ruby] code.

    Here's how it renders:

    This is a footnote[^1]

    A horizontal ruler follows:

    ---

    ## This is an h2 header

    ### This is an h3 header

    #### This is an h4 header

    ... and this is a blockquote:

    > A sentence should contain no unnecessary words, a paragraph no unnecessary 
    > sentences, for the same reason that a drawing should have no unnecessary 
    > lines and a machine no unnecessary parts. This requires not that the writer 
    > make all his sentences short, or that he avoid all detail and treat his 
    > subjects only in outline, but that every word tell.

    From [The Elements of Style][eos], [William Strunk][ws]


    ## Syntax highlighting

    posts include syntax highlighting, via [pygments][pyg]:

    Javascript

    ```js
    let fact = 1

    for (i = 1; i <= number; i++)
      fact *= i

    console.log(`The factorial of ${number} is ${fact}.`)
    ```

    Ruby


    ```ruby
    a = [:foo, 'bar', 2]

    a.reverse_each do |element| 
    puts "#{element.class} #{element}" 
    end
    ```

    Bash

    ```bash
    #!/bin/bash

    i=1
    while [[ $i -le 10 ]] ; do
    echo "$i"
    (( i += 1 ))
    done
    ```

    ## More

    this is a list:

    - Oranges
    - Apples
    - Peaches

    ... and this is an SVG image of **Felix The Housecat**:


    ![Felix the Housecat, the cartoon]({{root_url}}felix.svg "Felix the Housecat")

    This project was inspired by: The [1kb club][1kb].


    ### Footnotes


    [^1]: Garner, Bryan A. (2009). Garner on Language and Writing: Selected Essays z
        and Speeches of Bryan A. Garner. Chicago: American Bar Association. p. 295. 
        ISBN 978-1-60442-445-4.


    [1kb]: https://1kb.club/
    [bp]: https://en.wikipedia.org/wiki/Blaise_Pascal
    [eos]: https://en.wikipedia.org/wiki/The_Elements_of_Style
    [ws]: https://en.wikipedia.org/wiki/William_Strunk_Jr.
    [ruby]: https://www.ruby-lang.org/en/
    [nix]: https://github.com/nicholaswmin/nix
    [pyg]: https://pygments.org/
    [gfm]: https://github.github.com/gfm/

- posts/another-post.md: |
    # just another post

    21-11-2020

    This is another sample post, written in **Markdown**.

    You can add as many as you want in this folder but ensure each post:

    - has an `h1` heading at the very top
    - has an empty line following it
    - and a date on the 3rd line

    ... just like this post.

- public/style.css: |
    :root {
      --fonts: Menlo, monospace;
      --font-size: 100%; --font: #555; --font-light: #777; --font-lighter: #aaa;
      --bg: #fafafa;  --primary: #00695C; --secondary: #3700B3;
    }
    
     *, *:after, *:before { box-sizing: border-box; }
     body::selection { background: #999; }

    html {
      font-family: var(--fonts); font-size: var(--font-size);
      -webkit-font-smoothing: antialiased; -webkit-text-size-adjust: 100%; 
      line-height: 1.15;
    }
    
    body { 
      max-width: 90ex; margin: 0 auto; 
      background: var(--bg-col); color: var(--font-col); overflow-y: scroll; 
    }
    
    main { padding: 0;  margin: 0 auto; }
    nav, footer { ul { display: block; margin: 0; padding-left: 0; }
      li { display: inline-block; margin-right: 2em; a { color: var(--font-col); } }
      small,li {  display: inline-block; margin-top: 2em; }
    }

    /* Typebase.css (avoid changing, they keep vertical rhythm) */
    p { line-height: 1.5rem;  margin-top: 1.5rem; margin-bottom: 0; }
    ul, ol { margin-top: 1.5rem; margin-bottom: 1.5rem; }
    ul li, ol li { line-height: 1.5rem; }
    ul ul, ol ul, ul ol, ol ol { margin-top: 0;  margin-bottom: 0; }
    blockquote { line-height: 1.5rem; margin-top: 1.5rem; margin-bottom: 1.5rem; }
    
    h1,h2,h3,h4,h5,h6 { margin-top: 1.5rem; margin-bottom: 0; line-height: 1.5rem; }
    h1 { font-size: 4.2421rem; line-height: 4.5rem; margin-top: 3rem; }
    h2 { font-size: 2.8281rem; line-height: 3.1rem; margin-top: 3rem; }
    h3 { font-size: 1.4114rem; } h4 { font-size: 0.7071rem; }
    h5 { font-size: 0.4713rem; } h6 { font-size: 0.3535rem; }
    
    table { margin-top: 1.5rem; border-spacing: 0px; border-collapse: collapse; }
    table td, table th {  padding: 0; line-height: 33px; }
    code { vertical-align: bottom; }
    .lead { font-size: 1.414rem; }
    .hug { margin-top: 0; }
    
    /* @nicholaswmin */
    img { margin: 0; max-width: 100%; }
    pre {
      padding: 2em; border-radius: 6px; word-wrap: break-word;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.24); word-wrap: break-word;
      code {  white-space: break-spaces; }
    }

- public/felix.svg: |
    <svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" viewBox="0 0 595 654"><style>.st1{fill:#fff}</style><path id="Warstwa_2" d="M493 481c-7-3-19-4-36 3l-35-17c99 4 208-177 128-202 0 0-23-7-40 7-26 21 4 123-89 144 0 0 8-24-15-48l55-31s1-37-2-47l-98-9s24-18 33-49c0 0 20-21 35-28 0 0-13-10-21-9l27-34c-30-27-56-75-66-145 0 0-4-5-9-1-5 3-36 44-53 48s-30-5-72 4c0 0-33-25-37-40-9-9-12 3-12 3s-3 52-8 57l-21 21-8-18s7-16 19-18l-17-33s-16 5-29 22c-13-19-26-32-36-34-2-1-7-2-12 0s-8 7-9 9c0 0-10-9-16-4-6 4-13 22-5 34 0 0-30-10-5 66 7 17 21 48 59 51l107 149 7-10c4-5 10-7 13-9 2 1 6 3 10 3h10l4 1 4 3-2 3s-9-6-17-5c-8 0-21 2-27 21 0 0-16 0-28 18-13 17-34 48-17 61s33-4 33-4 6 39 45 33c0 0-9 2 0 17l-19 16s-11-52-59-34-44 160 36 171c62 1 57-41 57-41l60-52s24 3 35-1l62 37s-33 84 56 84c5 0 21-1 33-10 42-28 33-136-8-153zM354 340l-5-14 18 1-13 13z"/>  <g id="Warstwa_3">    <path d="M158 224c2 11 7 36 26 57 11 12 23 19 33 25 9 5 14 6 18 7 8 2 15 0 27-2 6-1 98-17 113-74 0-6-1-15-7-21-10-10-32-10-51 6-7 4-18 9-31 10-7 1-27 2-39-11l-4-6-3-2-49 9-8-1s-8 9-25 3zm28-116c-7 5-17 22-24 41-8 25-10 63 4 69 4 2 11 1 20-5 10-4 12-6 20-8 7-2 8-8 8-8s15-56 13-70c-1-15-4-21-9-24-12-8-24-1-32 5z" class="st1"/><path d="m221 196 8-41 5-24c4-9 8-21 19-30 9-8 18-11 23-12 4-1 20-4 38 3 26 9 36 40 35 64-2 28-20 46-25 50-4 5-22 21-46 20-10-1-29-4-31-14-3-11-14-1-14-1l-14-5 2-10z" class="st1"/>  </g>  <g id="Warstwa_4"><path d="M188 236c-7-8-6-21-1-29 8-11 23-11 30-11 7 1 15 1 20 7 6 8 4 19 0 26-8 14-26 15-28 15-4 0-14 0-21-8z"/><path d="M177 242c6 7 25 26 55 31 51 8 79-22 88-37l-5-1c-6-1-11 1-14 2-2-2 24-14 38 7 0 0-9-7-12-6 0 0-37 50-76 50s-68-32-74-38l5 11c0 1-4 7-5 3s-6-21-2-26c2-1 2 4 2 4z"/> </g> <g id="Warstwa_5"><path d="M212 249s-2 1 1 6 4 8 6 7-5-14-7-13z"/><path fill="none" stroke="#000" stroke-linecap="round" stroke-miterlimit="10" stroke-width="3" d="M344 220 478 82M353 221l139-115M134 227l-49-15m61 32-58-3"/></g><g id="Warstwa_6"><ellipse cx="336" cy="149.3" rx="12" ry="25.4" transform="rotate(12 336 149)"/><ellipse cx="213.3" cy="154.7" rx="12" ry="25.4" transform="rotate(12 213 155)"/></g></svg>

- public/highlight.css: |
    /*
     * Syntax Highlighting CSS (Pygments)  
     * Autogenerated by Rouge Gem using: 
     *
     * puts Rouge::Themes::Github.mode(:light).render(scope: '.highlight') 
     */

    .highlight table td{padding:5px}.highlight table pre{margin:0}.highlight,.highlight .w{color:#24292f;background-color:#f6f8fa}.highlight .k,.highlight .kd,.highlight .kn,.highlight .kp,.highlight .kr,.highlight .kt,.highlight .kv{color:#cf222e}.highlight .gr{color:#f6f8fa}.highlight .gd{color:#82071e;background-color:#ffebe9}.highlight .nb,.highlight .nc,.highlight .nn,.highlight .no{color:#953800}.highlight .na,.highlight .nt,.highlight .sr{color:#116329}.highlight .gi{color:#116329;background-color:#dafbe1}.highlight .ges{font-weight:700;font-style:italic}.highlight .bp,.highlight .il,.highlight .kc,.highlight .l,.highlight .ld,.highlight .m,.highlight .mb,.highlight .mf,.highlight .mh,.highlight .mi,.highlight .mo,.highlight .mx,.highlight .ne,.highlight .nl,.highlight .nv,.highlight .o,.highlight .ow,.highlight .py,.highlight .sb,.highlight .vc,.highlight .vg,.highlight .vi,.highlight .vm{color:#0550ae}.highlight .gh,.highlight .gu{color:#0550ae;font-weight:700}.highlight .dl,.highlight .s,.highlight .s1,.highlight .s2,.highlight .sa,.highlight .sc,.highlight .sd,.highlight .se,.highlight .sh,.highlight .ss,.highlight .sx{color:#0a3069}.highlight .fm,.highlight .nd,.highlight .nf{color:#8250df}.highlight .err{color:#f6f8fa;background-color:#82071e}.highlight .c,.highlight .c1,.highlight .cd,.highlight .ch,.highlight .cm,.highlight .cp,.highlight .cpf,.highlight .cs,.highlight .gl,.highlight .gt{color:#6e7781}.highlight .ni,.highlight .si{color:#24292f}.highlight .ge{color:#24292f;font-style:italic}.highlight .gs{color:#24292f;font-weight:700}
-->
