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
    end + @pages.flatten.uniq do | page | page.path end
    
    pages
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

  def self.saves mod
    @@readwriter = mod
    self
  end

  def self.glob glob
    glob = File.join(@@src, glob)

    (@@readwriter.glob glob).map do | path |  
      self.new([path, @@readwriter.read(path.to_s)]) 
    end
  end

  def write 
    @@readwriter.write(File.join(@@dest, @path), @data) 
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
    FileUtils.mkdir_p Pathname.new(path.to_s).dirname
    File.write path, data
  
    puts "- wrote: #{path}"  
  end
end

  
def build config
  DTO
    .saves(Filesystem)
    .using(src: config['src'], dest: config['dest'])
  
  Site.new(config:)
    .using(DTO.glob('_layouts/*.html').map(&Layout.from_dto))
    .add(
      DTO.glob('posts/*.md').map(&Post.from_dto) +
      DTO.glob('pages/*.md').map(&Page.from_dto) +
      DTO.glob('index.md').map(&Index.from_dto)
    )
    .compile(config) 
    .map(&:to_dto) 
    .map(&:write)
  
  FileUtils.cp_r('public/.', "#{config['dest']}/public")
end

def serve port:, dest:
  server = WEBrick::HTTPServer.new :Port => port, :DocumentRoot => dest
  server.mount 'public', WEBrick::HTTPServlet::FileHandler, "#{dest}/public/"

  trap 'INT' do server.shutdown exit true end

  server.start
end

def init
  DTO.saves(Filesystem).using(dest: '.')

  [
    # config
    ['_config.yml', "name: 'A bunny blog'¦author: 'John Doe'¦favicon: 🐇¦¦dest: './build'¦¦"],

    # layouts
    ['_layouts/header.html', "<!doctype html>¦<html lang=┊en┊>¦¦<head>¦  <meta charset=┊utf-8┊>¦  <meta name=┊viewport┊ content=┊width=device-width, initial-scale=1┊>¦  <meta name=┊description┊ content=┊a blog site┊>¦  <link rel=┊icon┊ href=┊data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'><text x='0' y='14'>{{favicon}}</text></svg>┊>¦  <link rel=┊stylesheet┊ href=┊/public/style.css┊>¦  <title>{{title}}</title>¦</head> ¦¦<nav>¦  <ul>¦    <li><a href=┊/┊>posts</a></li>¦    <li><a href=┊/cv┊>author </a></li>¦  </ul>¦</nav>¦"],
    [ '_layouts/footer.html', "<footer>¦  <small> <small> > <a href=┊https://1kb.club/┊>{{bytes}} bytes</a> </small></small>¦</footer>¦" ],

    # posts
    [ 'posts/primordial-post.md', "# what is this?¦¦21-10-2021¦¦ You're viewing a sample `Post`.¦¦¦¦  This site is an example of minimalism in software design; otherwise ¦known as **conciseness**. ¦¦It's generated using a **minimal** static-site generator, which renders¦posts from `Markdown`.¦¦---¦¦in common usage and linguistics, concision  (also called conciseness, ¦succinctness,[^1] terseness, brevity, or laconicism) is a communication ¦principle[^2] of eliminating redundancy,[^3] generally  achieved by using as ¦few words as possible in  a sentence while preserving its meaning. ¦¦> I have made this longer than usual, only because I have not ¦> had the time to make it shorter.¦¦[Blaise Pascal][bp]¦¦This is a list¦¦- apples¦- oranges¦- ~~grapes~~¦¦Heres a picture of Felix The Housecat to check how images render:¦¦![An image of Felix the Housecat, a cartoon](/public/felix.webp ┊Felix the Cat┊)¦¦This project was inspired by: The [1kb club][1kb].¦¦[1kb]: https://1kb.club/¦[bp]: https://en.wikipedia.org/wiki/Blaise_Pascal¦¦### Footnotes¦¦[^1]: Garner, Bryan A. (2009). Garner on Language and Writing: Selected Essays z¦      and Speeches of Bryan A. Garner. Chicago: American Bar Association. p. 295. ¦      ISBN 978-1-60442-445-4.¦¦[^2]: William Strunk (1918). The Elements of Style.¦¦[^3]: UNT Writing Lab. ┊Concision, Clarity, and Cohesion.┊ ¦      Accessed June 19, 2012. Link.¦¦"
    ],
    ['posts/another-post.md', "# just another post ¦¦2020-10-15¦¦> posts are good, mkay?¦ ¦this is just another post, because the 1st one might be lonely.¦¦thanks,¦¦"],

    # pages
    ['pages/terms.md', "¦## Terms & Conditions¦¦> not really gonna write terms and conditions¦¦ This is a sample `Page`. it's like a post but not quite. ¦¦> It's is written in `Markdown` but doesn't support code syntax highlighting ¦> nor is it included in any Post lists.¦¦You can add as many as you want within this folder.¦¦Merci¦"],
    ['pages/index.md', "hello world, this is sample post generated by nix" ],
  
    # CSS 
    ['public/style.css', ":root {¦  --bg-color: #fafafa; ¦  --bg-color-full: #fff;¦  --primary-color: #00695C;¦  --secondary-color: #3700B3;¦  --font-color: #555; ¦  --font-color-lighter: #777;¦  --font-color-lightest: #ccc;¦  --font-size: 14x; ¦}¦¦¦@media (prefers-color-scheme: dark) {¦  :root {¦    --bg-color: #222; ¦    --bg-color-full: #111;¦    --primary-color: #0097A7;¦    --font-color: #ccc; ¦    --font-color-lighter: #aaa;¦    --font-color-lightest: #666;¦  }¦}¦¦/* Resets */¦¦* { ¦  font-family: monospace; font-size: var(--font-size);¦  font-weight:normal; text-decoration: none;¦}¦¦body { ¦  /* must acc. 80-chars in code */¦  max-width: 110ex; margin: 1em auto; padding: 0 1em;¦  background: var(--bg-color); color: var(--font-color); ¦  ::selection { background: var(--font-color-lightest); }¦¦  overflow-y: scroll;¦  @media print { width: auto; }¦}¦¦/* --- Typography ---*/¦¦p { padding: 1em 0; }¦a { color: var(--primary-color); font-size: inherit; }¦a:hover { color: var(--link-color-hover);  }¦blockquote { font-style: italic; }¦blockquote > p { display:inline; }¦¦h1, h2, h3, h4, h5, p, blockquote, pre { line-height: 1.5; padding: 0.5em 0; }¦h1 { font-size: 1.75em; } h2 { font-size: 1.5em; } h3 { font-size: 1.25em;  }¦h4, h4 *, small, small * { font-size: 0.9em; color: var(--font-color-lighter); }¦¦h1, h2, h3 { margin: 1.5em 0 1em 0; }¦h1, h2 { border-bottom: 1px solid var(--font-color-lightest); }¦¦/* --- Mav/Main/Footer ---*/¦¦main { padding: 1.5em 0; img { margin: 2em 0; max-width: 100%; } }¦nav, footer {  @media print { display: none; }  }¦¦/* --- Lists ---*/¦¦ul { ¦  display: block; padding-left: 1em; margin: 2em 0; list-style-type: '- ';¦ \th1, h2, h3, h4, h5, h6 { margin: 0; padding: 0.25em 0; } ¦  h3 { color: var(--primary-color); }¦  li { margin: 1em 0; }¦}¦¦/* Nav Lists */¦¦nav, footer {¦  padding: 1em 0;¦  ul { display: block; margin: 0; padding-left: 0; }¦\tli { display: inline-block; margin-right: 2em;  }¦\tli a { color: var(--font-color); }¦\tsmall { display: inline-block; margin-top: 2em; }¦}¦¦/* Postpage: title & date */¦.post { ¦  h1:first-of-type, h2:first-of-type { margin-bottom: 0; }¦  code { ¦    padding: 2px 6px; border-radius: 0; font-size: 1em; ¦    background: var(--font-color-lightest); ¦  }¦¦  pre {¦    font-size: 1.1em; padding: 2em; border-radius: 6px;¦    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.24); word-wrap: break-word;¦    background: var(--bg-color-full);¦    code {  ¦      display: block; ¦      background: var(--bg-color-full); white-space: break-spaces; ¦    }¦  }¦    ¦  blockquote { ¦    background: none;¦    border-left: 2px solid var(--font-color-lightest);¦    border-radius: 0; margin: 2em 0; padding: 1em; font-style: normal;¦    p { color: var(--font-color-lighter); }¦  }¦  ¦  hr { margin: 2.5em 0 2.5em 0; border: 0.5px solid; border-color: var(--font-color-lightest);}¦  ¦  .footnotes { margin-top: 2em; }¦}¦"],
    ['public/styles/highlight', ".highlight table td { padding: 5px; }¦.highlight table pre { margin: 0; }¦.highlight, .highlight .w {¦  color: #24292f;¦  background-color: #f6f8fa;¦}¦.highlight .k, .highlight .kd, .highlight .kn, .highlight .kp, .highlight .kr, .highlight .kt, .highlight .kv {¦  color: #cf222e;¦}¦.highlight .gr {¦  color: #f6f8fa;¦}¦.highlight .gd {¦  color: #82071e;¦  background-color: #ffebe9;¦}¦.highlight .nb {¦  color: #953800;¦}¦.highlight .nc {¦  color: #953800;¦}¦.highlight .no {¦  color: #953800;¦}¦.highlight .nn {¦  color: #953800;¦}¦.highlight .sr {¦  color: #116329;¦}¦.highlight .na {¦  color: #116329;¦}¦.highlight .nt {¦  color: #116329;¦}¦.highlight .gi {¦  color: #116329;¦  background-color: #dafbe1;¦}¦.highlight .ges {¦  font-weight: bold;¦  font-style: italic;¦}¦.highlight .kc {¦  color: #0550ae;¦}¦.highlight .l, .highlight .ld, .highlight .m, .highlight .mb, .highlight .mf, .highlight .mh, .highlight .mi, .highlight .il, .highlight .mo, .highlight .mx {¦  color: #0550ae;¦}¦.highlight .sb {¦  color: #0550ae;¦}¦.highlight .bp {¦  color: #0550ae;¦}¦.highlight .ne {¦  color: #0550ae;¦}¦.highlight .nl {¦  color: #0550ae;¦}¦.highlight .py {¦  color: #0550ae;¦}¦.highlight .nv, .highlight .vc, .highlight .vg, .highlight .vi, .highlight .vm {¦  color: #0550ae;¦}¦.highlight .o, .highlight .ow {¦  color: #0550ae;¦}¦.highlight .gh {¦  color: #0550ae;¦  font-weight: bold;¦}¦.highlight .gu {¦  color: #0550ae;¦  font-weight: bold;¦}¦.highlight .s, .highlight .sa, .highlight .sc, .highlight .dl, .highlight .sd, .highlight .s2, .highlight .se, .highlight .sh, .highlight .sx, .highlight .s1, .highlight .ss {¦  color: #0a3069;¦}¦.highlight .nd {¦  color: #8250df;¦}¦.highlight .nf, .highlight .fm {¦  color: #8250df;¦}¦.highlight .err {¦  color: #f6f8fa;¦  background-color: #82071e;¦}¦.highlight .c, .highlight .ch, .highlight .cd, .highlight .cm, .highlight .cp, .highlight .cpf, .highlight .c1, .highlight .cs {¦  color: #6e7781;¦}¦.highlight .gl {¦  color: #6e7781;¦}¦.highlight .gt {¦  color: #6e7781;¦}¦.highlight .ni {¦  color: #24292f;¦}¦.highlight .si {¦  color: #24292f;¦}¦.highlight .ge {¦  color: #24292f;¦  font-style: italic;¦}¦.highlight .gs {¦  color: #24292f;¦  font-weight: bold;¦}"]
  ]
  .map(&DTO.new)
  .each(&:write)
end

# --- Main -----

build YAML.load_file('./_config.yml')

puts "\e[0;32m- build: ok\e[0m"

serve port: 8000, dest: 'build'
