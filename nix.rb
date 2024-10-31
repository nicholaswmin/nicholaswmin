#!/usr/bin/env ruby

# # The MIT License
#
# Nicholas Kyriakides
# @nicholaswmin
# 
# Original idea: 
# - "wruby" by Bradley Taunt
# 
# The MIT License  
# 
# Although this is an entirely different project, 
# rewritten from scratch in OOP & deviating 
# in both functionality & form, it would not have 
# been possible without "wruby".
# 
# Check out wruby here: https://git.btxx.org/wruby/tree/

# @todo turn on: $VERBOSE = true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'optparse', '~> 0.4.0', require: true
  gem 'webrick', '~> 1.8.2', require: true
  gem 'kramdown', '~> 2.4.0', require: true
  gem 'kramdown-parser-gfm', '~> 1.1.0', require: true
  gem 'rouge', '~> 4.4.0', require: true
  gem 'logger', '~> 1.6.0', require: false
end

require 'fileutils'
require 'date'
require 'find'
require 'yaml'

# This document is expected (might be out of date) 
# to consist of:
# 
#  - Classes:
#   - A main `class` holding everything together.
#   - A bunch of `Page`-like classes, each representing 
#     a different page formats.
#  - possibly some filesystem helpers
#  - a main `build()` function 
# 
# The classes are *decoupled* from the filesystem and shouldn't 
# mess with it. They shouldn't use or know abou `File.read/write` or
# anything of the sort. This separates the concerns and allows for easy-peasy
# unit testing of the core logic without touching a filesystem itself.
# 
# @TODO
# - [ ] An init method
# - [ ] Tests
# - [ ] Error handling
# - [x] Unique page class
# - [ ] Bring RSS back
# - [ ] Style tweaks
# - [ ] use https://rubystyle.guide/#percent-q-shorthand
# - [ ] Use option parser for CLI args: https://ruby-doc.org/stdlib-2.7.1/libdoc/optparse/rdoc/OptionParser.html
# - [ ] consider ERB for templating  
# - [ ] fix dark mode css on code snippets in post
# - [ ] support nested config for variables
# - [ ] All writable should extend Writable? (too much fs coupling?)
# - [ ] Header/Footer are layouts too?
# - [ ] Fix path resolution (does not use __dirname)
# --- Classes ---

# The main class. It holds all `Page`-like instances.
# 
# - When `compile` is called it compiles every page
#   and returns a list of `Files`-like instances,
#   which is the blog pages

class Site
  def initialize config:
    @config = config.clone
    @layouts = []
    @pages = []
  end

  def posts 
    @pages.filter do | page | page.class.to_s.downcase.include? 'post' end
  end
  
  def using layouts
    @layouts = (layouts.map do | layout | [layout.name, layout] end).to_h

    self
  end
  
  def compile variables
    pages = @pages.map do | page | 
      page.compile(layouts: @layouts, ctx: { posts:, variables: }) 
    end

    pages.flatten.uniq do | page | page.path end
  end

  def add pages
    [pages].flatten.each do | page | @pages.push page end

    self
  end
  
  def self.from_dto
    Proc.new do | dto | self.new path: dto.path, html: dto.data end
  end
end


class DTO 
  attr_reader :path, :data

  @@src; @@dest; @@readwriter = nil

  def initialize((path, data))
    @path = path
    @data = data
  end
  
  def self.using src: '', dest:
    @@src  = src
    @@dest = dest

    self
  end

  def self.adapter mod
    @@readwriter = mod
    self
  end

  def self.glob glob
    glob = File.join(@@src, glob)

    (@@readwriter.glob glob).map do | path |  
      self.new([path, @@readwriter.read(path)]) 
    end
  end

  def write 
    @@readwriter.write(Pathname.new(File.join(@@dest, @path)), @data)
  end
end


class Layout 
  attr_reader :name

  def initialize path:, html:
    @name = path.basename(path.extname).to_s
    @html = html
  end
  
  def self.from_dto
    Proc.new do | dto | self.new path: dto.path, html: dto.data end
  end
  
  def to_s
    @html
  end
end


class HTMLPage
  attr_reader :path, :title, :assets, :data

  def initialize path:, title:, assets: []
    @path = Pathname.new(path.to_s)
    @title = title ||= @path.basename.to_s
    @assets = []
    @data = nil
    
    @type = self.class.to_s.downcase
    @name = @path.basename(@path.extname).to_s
  end

  def compile layouts:, ctx:   
    html = <<~BODY
      #{layouts['header']}
        <main class="#{@type} #{@name}">
          #{to_html(ctx)}
        </main>
       #{layouts['footer']}
       #{[assets].flatten.reduce('', :+)}
      BODY

    @data = replace html, ctx[:variables]
    
    self
  end
  
  def to_dto() DTO.new([@path, @data]) end

  #todo use erb?
  private def replace html, variables
    { 
      **variables,
      "title" => @title, 
      "bytes" => html.gsub(/\s+/, '').bytesize.to_s 
    }.reduce html do | html, (variable, value) | 
      html = html.gsub('{{' + variable.to_s + '}}', value.to_s) 
    end
  end
  
  private def to_list items, to_list_item
    list = <<~BODY.squeeze("\n")
      <ul class="list">
        #{items.reduce('',&to_list_item)}
      </ul>
    BODY
  end
end

# --- Userland (supposedly) ---- 

# @TODO this feels wrong?
class MarkdownPage < HTMLPage
  def initialize path, markdown, title = nil
    super(path:, title: title ? title : to_title(markdown))
    @markdown = markdown
  end
  
  def to_html ctx
    Kramdown::Document.new(@markdown, {
      input: 'GFM', auto_ids: true,
      syntax_highlighter: 'rouge'
    }).to_html
  end
  
  def to_title markdown
    markdown.lines.first&.start_with?('# ') ? 
      markdown.lines.first[2..-1].strip : 
      'Untitled'
  end
  
  def self.from_dto
    Proc.new do | dto | self.new(dto.path, dto.data) end
  end
end

class Page < MarkdownPage 
  def initialize path, markdown
    super "/#{path.basename(path.extname)}/index.html", markdown
  end
end

class Post < MarkdownPage
  attr_reader :date, :link
  
  def initialize path, markdown
    super "/posts/#{path.basename(path.extname)}/index.html", markdown

    @date = Date.parse(markdown.lines[2]&.strip || '') rescue Date.today
    @link = @path.dirname
  end
  
  def to_html ctx
    super(ctx) + '<link rel="stylesheet" href="/public/highlight.css"><link>'
  end

end

class Index < MarkdownPage 
  def initialize path, markdown
    super('/index.html', markdown, 'Home')
  end

  def to_html ctx
    super(ctx) + to_list(ctx[:posts], to_list_item = -> (list, post) { 
      list << post = <<~BODY
      <li>
        <a href="#{post.link}">
          <h3>#{post.title}</h3> 
          <small>
            <time datetime="#{post.date}">
              #{post.date.strftime('%b, %Y')}
            </time>
          </small>
        </a>
      </li>
      BODY
    })
  end
end


# --- Main ---- 

module Filesystem 
  def self.glob glob 
    Pathname.glob(glob) 
  end
  
  def self.read path 
    File.read(path) 
  end
  
  def self.write path, data
    FileUtils.mkdir_p path.dirname

    if File.exist? path 
      return warn "skipped: #{path}. Already exists" 
    end
    
    File.write path, data; 
    puts "- wrote: #{path}"  
  end
end

  
def build config
  FileUtils.rm_rf Dir.glob config['dest'] + '/*'

  DTO
    .adapter(Filesystem)
    .using(src: config['src'], dest: config['dest'])
  
  Site.new(config:)
    .using(DTO.glob('_layouts/*.html').map(&Layout.from_dto))
    .add(
      DTO.glob('posts/*.md').map(&Post.from_dto) +
      DTO.glob('pages/*.md').map(&Page.from_dto) +
      DTO.glob('pages/index.md').map(&Index.from_dto)
    )
    .compile(config) 
    .map(&:to_dto) 
    .map(&:write)
  
  FileUtils.cp_r('public/.', "#{config['dest']}/public")
end

def parse_cli
  option = {}
  parser = OptionParser.new
  parser.on '-i XXX', '--init', 'create sample at specified folder', String
  parser.on '-s XXX', '--serve', 'serve at specified port', Integer
  parser.parse!(into: option)

  option
end

def serve port: 8080, dest: './build'
  server = WEBrick::HTTPServer.new :Port => port, :DocumentRoot => dest
  server.mount 'public', WEBrick::HTTPServlet::FileHandler, "#{dest}/public/"

  trap 'INT' do server.shutdown exit true end

  server.start
end

def init dir: 'blog'
  [
    # this
    [File.basename(__FILE__), File.read(__FILE__), 'noexpand'],
    # config
    ['_config.yml', "name: 'A bunny blog'¦author: 'John Doe'¦favicon: 🐇¦¦src: './'¦dest: './build'¦¦"],
    # layouts
    ['_layouts/header.html', "<!doctype html>¦<html lang=┊en┊>¦¦<head>¦  <meta charset=┊utf-8┊>¦  <meta name=┊viewport┊ content=┊width=device-width, initial-scale=1┊>¦  <meta name=┊description┊ content=┊a blog site┊>¦  <link rel=┊icon┊ href=┊data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'><text x='0' y='14'>{{favicon}}</text></svg>┊>¦  <link rel=┊stylesheet┊ href=┊/public/style.css┊>¦  <title>{{title}}</title>¦</head> ¦¦<nav>¦  <ul>¦    <li><a href=┊/┊>posts</a></li>¦    <li><a href=┊/about┊>about </a></li>¦  </ul>¦</nav>¦"], [ '_layouts/footer.html', "<footer>¦  <small> <small> > <a href=┊https://1kb.club/┊>{{bytes}} bytes</a> </small></small>¦</footer>¦" ],
    # posts
    [ 
      'posts/first-post.md', "# what is this?¦¦21-10-2021¦¦You're viewing a sample `Post`.¦¦ This site is an example of minimalism in software design; otherwise ¦known as **conciseness**. ¦¦It's generated using a **minimal** static-site generator, which renders¦posts from `Markdown`.¦¦> I have made this longer than usual, only because I have not ¦> had the time to make it shorter.¦¦[Blaise Pascal][bp]¦¦This is a list¦¦- apples¦- oranges¦- ~~grapes~~¦¦Heres a picture of Felix The Housecat to check how images render:¦¦![An image of Felix the Housecat, a cartoon](/public/felix.svg ┊Felix the Cat┊)¦¦This project was inspired by: The [1kb club][1kb].¦¦[1kb]: https://1kb.club/¦[bp]: https://en.wikipedia.org/wiki/Blaise_Pascal¦¦### Footnotes¦¦[^1]: Garner, Bryan A. (2009). Garner on Language and Writing: Selected Essays z¦      and Speeches of Bryan A. Garner. Chicago: American Bar Association. p. 295. ¦      ISBN 978-1-60442-445-4.¦¦[^2]: William Strunk (1918). The Elements of Style.¦¦[^3]: UNT Writing Lab. ┊Concision, Clarity, and Cohesion.┊ ¦      Accessed June 19, 2012. Link.¦¦"
    ], 
    ['posts/another-post.md', "# just another post ¦¦2020-10-15¦¦> posts are good, mkay?¦ ¦this is just another post, because the 1st one might be lonely.¦¦thanks,¦¦"],
    # pages
    ['pages/index.md', "hello world :)" ], ['pages/about.md', "a sample About Us page. Nothing special."],

    # Felix the housecat 
    ['public/felix.svg', "<svg xmlns=┊http://www.w3.org/2000/svg┊ xml:space=┊preserve┊ viewBox=┊0 0 595 654┊><style>.st1{fill:#fff}</style><path id=┊Warstwa_2┊ d=┊M493 481c-7-3-19-4-36 3l-35-17c99 4 208-177 128-202 0 0-23-7-40 7-26 21 4 123-89 144 0 0 8-24-15-48l55-31s1-37-2-47l-98-9s24-18 33-49c0 0 20-21 35-28 0 0-13-10-21-9l27-34c-30-27-56-75-66-145 0 0-4-5-9-1-5 3-36 44-53 48s-30-5-72 4c0 0-33-25-37-40-9-9-12 3-12 3s-3 52-8 57l-21 21-8-18s7-16 19-18l-17-33s-16 5-29 22c-13-19-26-32-36-34-2-1-7-2-12 0s-8 7-9 9c0 0-10-9-16-4-6 4-13 22-5 34 0 0-30-10-5 66 7 17 21 48 59 51l107 149 7-10c4-5 10-7 13-9 2 1 6 3 10 3h10l4 1 4 3-2 3s-9-6-17-5c-8 0-21 2-27 21 0 0-16 0-28 18-13 17-34 48-17 61s33-4 33-4 6 39 45 33c0 0-9 2 0 17l-19 16s-11-52-59-34-44 160 36 171c62 1 57-41 57-41l60-52s24 3 35-1l62 37s-33 84 56 84c5 0 21-1 33-10 42-28 33-136-8-153zM354 340l-5-14 18 1-13 13z┊/>  <g id=┊Warstwa_3┊>    <path d=┊M158 224c2 11 7 36 26 57 11 12 23 19 33 25 9 5 14 6 18 7 8 2 15 0 27-2 6-1 98-17 113-74 0-6-1-15-7-21-10-10-32-10-51 6-7 4-18 9-31 10-7 1-27 2-39-11l-4-6-3-2-49 9-8-1s-8 9-25 3zm28-116c-7 5-17 22-24 41-8 25-10 63 4 69 4 2 11 1 20-5 10-4 12-6 20-8 7-2 8-8 8-8s15-56 13-70c-1-15-4-21-9-24-12-8-24-1-32 5z┊ class=┊st1┊/><path d=┊m221 196 8-41 5-24c4-9 8-21 19-30 9-8 18-11 23-12 4-1 20-4 38 3 26 9 36 40 35 64-2 28-20 46-25 50-4 5-22 21-46 20-10-1-29-4-31-14-3-11-14-1-14-1l-14-5 2-10z┊ class=┊st1┊/>  </g>  <g id=┊Warstwa_4┊><path d=┊M188 236c-7-8-6-21-1-29 8-11 23-11 30-11 7 1 15 1 20 7 6 8 4 19 0 26-8 14-26 15-28 15-4 0-14 0-21-8z┊/><path d=┊M177 242c6 7 25 26 55 31 51 8 79-22 88-37l-5-1c-6-1-11 1-14 2-2-2 24-14 38 7 0 0-9-7-12-6 0 0-37 50-76 50s-68-32-74-38l5 11c0 1-4 7-5 3s-6-21-2-26c2-1 2 4 2 4z┊/> </g> <g id=┊Warstwa_5┊><path d=┊M212 249s-2 1 1 6 4 8 6 7-5-14-7-13z┊/><path fill=┊none┊ stroke=┊#000┊ stroke-linecap=┊round┊ stroke-miterlimit=┊10┊ stroke-width=┊3┊ d=┊M344 220 478 82M353 221l139-115M134 227l-49-15m61 32-58-3┊/></g><g id=┊Warstwa_6┊><ellipse cx=┊336┊ cy=┊149.3┊ rx=┊12┊ ry=┊25.4┊ transform=┊rotate(12 336 149)┊/><ellipse cx=┊213.3┊ cy=┊154.7┊ rx=┊12┊ ry=┊25.4┊ transform=┊rotate(12 213 155)┊/></g></svg>"],
    # CSS
    ['public/style.css', ":root {¦  --bg-color: #fafafa; ¦  --bg-color-full: #fff;¦  --primary-color: #00695C;¦  --secondary-color: #3700B3;¦  --font-color: #555; ¦  --font-color-lighter: #777;¦  --font-color-lightest: #ccc;¦  --font-size: 14x; ¦}¦¦¦@media (prefers-color-scheme: dark) {¦  :root {¦    --bg-color: #222; ¦    --bg-color-full: #111;¦    --primary-color: #0097A7;¦    --font-color: #ccc; ¦    --font-color-lighter: #aaa;¦    --font-color-lightest: #666;¦  }¦}¦¦/* Resets */¦¦* { ¦  font-family: monospace; font-size: var(--font-size);¦  font-weight:normal; text-decoration: none;¦}¦¦body { ¦  /* must acc. 80-chars in code */¦  max-width: 110ex; margin: 1em auto; padding: 0 1em;¦  background: var(--bg-color); color: var(--font-color); ¦  ::selection { background: var(--font-color-lightest); }¦¦  overflow-y: scroll;¦  @media print { width: auto; }¦}¦¦/* --- Typography ---*/¦¦p { padding: 1em 0; }¦a { color: var(--primary-color); font-size: inherit; }¦a:hover { color: var(--link-color-hover);  }¦blockquote { font-style: italic; }¦blockquote > p { display:inline; }¦¦h1, h2, h3, h4, h5, p, blockquote, pre { line-height: 1.5; padding: 0.5em 0; }¦h1 { font-size: 1.75em; } h2 { font-size: 1.5em; } h3 { font-size: 1.25em;  }¦h4, h4 *, small, small * { font-size: 0.9em; color: var(--font-color-lighter); }¦¦h1, h2, h3 { margin: 1.5em 0 1em 0; }¦h1, h2 { border-bottom: 1px solid var(--font-color-lightest); }¦¦/* --- Mav/Main/Footer ---*/¦¦main { padding: 1.5em 0; img { margin: 2em 0; max-width: 100%; } }¦nav, footer {  @media print { display: none; }  }¦¦/* --- Lists ---*/¦¦ul { ¦  display: block; padding-left: 1em; margin: 2em 0; list-style-type: '- ';¦ \th1, h2, h3, h4, h5, h6 { margin: 0; padding: 0.25em 0; } ¦  h3 { color: var(--primary-color); }¦  li { margin: 1em 0; }¦}¦¦/* Nav Lists */¦¦nav, footer {¦  padding: 1em 0;¦  ul { display: block; margin: 0; padding-left: 0; }¦\tli { display: inline-block; margin-right: 2em;  }¦\tli a { color: var(--font-color); }¦\tsmall { display: inline-block; margin-top: 2em; }¦}¦¦/* Postpage: title & date */¦.post { ¦  h1:first-of-type, h2:first-of-type { margin-bottom: 0; }¦  code { ¦    padding: 2px 6px; border-radius: 0; font-size: 1em; ¦    background: var(--font-color-lightest); ¦  }¦¦  pre {¦    font-size: 1.1em; padding: 2em; border-radius: 6px;¦    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.24); word-wrap: break-word;¦    background: var(--bg-color-full);¦    code {  ¦      display: block; ¦      background: var(--bg-color-full); white-space: break-spaces; ¦    }¦  }¦    ¦  blockquote { ¦    background: none;¦    border-left: 2px solid var(--font-color-lightest);¦    border-radius: 0; margin: 2em 0; padding: 1em; font-style: normal;¦    p { color: var(--font-color-lighter); }¦  }¦  ¦  hr { margin: 2.5em 0 2.5em 0; border: 0.5px solid; border-color: var(--font-color-lightest);}¦  ¦  .footnotes { margin-top: 2em; }¦}¦"],
    # Syntax Highlight CSS
    ['public/highlight.css', Rouge::Themes::Github.mode(:light).render(scope: '.highlight').gsub("\n", '¦').gsub('"', '┊')]
  ]
  .map{| e | 
    [
      File.join(dir, e[0]), 
      e[2] == 'noexpand' ? e[1] : e[1].gsub('¦', "\n").gsub('┊', '"').strip
    ] 
  }
  .map(&DTO.adapter(Filesystem).using(dest: '.').method(:new))
  .each(&:write)  
end

# --- Main -----

flags = parse_cli

if flags[:init] 
  init dir: flags[:init] 
  puts "\e[0;32m- init:ok, output:#{flags[:init]}/\e[0m"
else
  config = YAML.load_file('./_config.yml')
  
  build config
  puts "\e[0;32m- build:ok, output:#{config[:dest]}\e[0m"

  if flags[:serve]
    puts "\e[0;34m- serve:ok, localhost:#{flags[:serve]}\e[0m"
    serve port: flags[:serve]
  end
end
