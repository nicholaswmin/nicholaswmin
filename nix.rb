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

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'kramdown', '~> 2.4.0', require: true
  gem 'kramdown-parser-gfm', '~> 1.1.0', require: true
  gem 'rouge', '~> 4.4.0', require: true
  gem 'logger', '~> 1.6.0', require: false
end

require 'fileutils'
require 'date'
require 'find'
require 'yaml'

puts "gems installed & loaded!"

# This document is comprised of:
# 
#  - Classes 
#  - couple of filesystem `read`/`write` functions
#  - the main `build()` function 
# 
# The classes are *decoupled* from the filesystem and shouldn't 
# mess with it. They shouldn't use or know abou `File.read/write` or
# anything of the sort. This separates the concerns and allows for easy-peasy
# unit testing of the core logic without touching a filesystem itself.
# 
# The filesystem `read` functions should get all neceessary files which
# are then used to generate classes.
# 
# The classes are responsible for generating the appropriate HTML structures
# 
# The filesystem functions then take those classes 
# and generate directories/write files out of them.
# 
# @TODO
# - [ ] An init method
# - [ ] Tests
# - [ ] Error handling
# - [ ] Unique page class
# - [ ] Bring RSS back
# - [ ] Style tweaks
# - [ ] Create `IndexPage` page as class, pass created stuff into the compile 
#       handler. Use them to compile a `<ul>`.
# - [ ] use https://rubystyle.guide/#percent-q-shorthand
# - [ ] Use option parser for CLI args: https://ruby-doc.org/stdlib-2.7.1/libdoc/optparse/rdoc/OptionParser.html


# --- Classes ---

# The main class. It holds all pages.
# When `compile` is called it compiles every page
# and returns a list of `Files`. 
# 
# Each `File` has a `path` & `contents` that, 
# if written as a file, will constitute a 
# fully-working website.

class Blog
  attr_reader :config

  def initialize config 
    @config = config

    @index = config[:index]
    @header= config[:header]
    @footer = config[:footer]

    @pages = []
  end

  def posts 
    @pages.filter do | page | 
      page.class.to_s.downcase.include? 'post' 
    end
  end
  
  def compile tokens = {} 
    generate_index

    res = @pages.map do | p | 
      p.compile({ '{{FAVICON}}' => @favicon, **tokens }) 
    end
    
    res = @pages + @pages.map do | p | p.assets end
    
    res.flatten.uniq do | p | p.path end
  end

  def add pages
    [pages].flatten.each do | page |
      @pages.push(page.prepend(@header).append(@footer).append(page.assets))
    end
    self
  end
  
  def generate_index
    list = posts.reduce(format('%<main>s \n <ul class="%<classname>s">', {
      main: Kramdown::Document.new(@index, input: 'GFM').to_html,
      classname: 'posts'
    })) do | list, post | 
      list << format(
        '%<open>s<a href="/%<path>s">%<head>s</a>%<date>s%<close>s', {
          open: '<li><article>',
          head: format('<h3>%<title>s</h3>', { title: post.title }),
          path: post.path,
          date: format('<h4><time datetime="%<date>s">%<year>s<time></h4>', {
            date: post.date, year: post.year
          }),
          close: '</article></li>'
        }
      ) << '</ul>'
    end

    add(HTMLPage.new(path: 'index.html', html: list))

    self
  end
end

class Asset 
  attr_reader :path, :contents
  
  def initialize filename, contents
    @path = Pathname.new("public/#{filename.split('/').last}")
    @contents = contents
  end
end

class CSS < Asset 
  def to_str
    format('<link rel="stylesheet" href="%<path>s"></link>', path: @path)
  end
end

class HTMLPage
  attr_reader :path, :assets, :title

  def initialize path:, html:, assets: [], title: 'home'
    @path = path.is_a?(Pathname) ? path : Pathname.new(path)
    @assets = assets
    @title = title ||= @path.basename.to_s
    @contents = ''
    @htmls = [html]
  end

  def contents
    @contents
  end
  
  def compile tokens = {}
    compiled = @htmls.reduce :+

    @contents = { 
      **tokens, "{{TITLE}}" => @title, 
      "{{BYTES}}" => compiled.bytesize.to_s 
    }.reduce compiled do | compiled, (placeholder, value) | 
      compiled = compiled.gsub(placeholder, value.to_s) 
    end

    
    @htmls = []

    self
  end
  
  def prepend htmls  
    [htmls].flatten.each do | html |
      @htmls.unshift html
    end
    
    self
  end
  
  def append htmls  
    [htmls].flatten.each do | html |
      @htmls.push html
    end

    self
  end  
end

# --- Userland (supposedly) ---- 

class MDPage < HTMLPage
  def initialize path:, markdown:
    super(
      path:,
      title: parse_title(markdown), 
      html: Kramdown::Document.new(markdown, input: 'GFM').to_html)
  end
  
  def parse_title markdown
    markdown.lines.first&.start_with?('# ') ? 
      markdown.lines.first[2..-1].strip : 
      'Blog Index'
  end

  def self.from reader, glob 
    Pathname.glob(glob).map do | path |
      self.new(path:, markdown: reader.call(path) )
    end
  end
end

class Page < MDPage 
  def initialize path:, markdown: 
    super(path: "#{path.basename(path.extname)}.html", markdown:)
  end
end

class Post < MDPage
  attr_reader :date, :year

  def initialize path:, markdown:, assets: []
    super(path: "posts/#{path.basename(path.extname)}.html", markdown:)
    @assets = [
      CSS.new('hl.css', Rouge::Themes::Github.mode(:light).render(scope: '.hl'))
    ]
    
    @date = Date.parse(markdown.lines[2]&.strip || '') rescue Date.today
    @year = @date.strftime '%b, %Y'
  end
end

# --- Build function ---- 

def build config
  reader_fn = Proc.new do | path | File.read path end

  Blog.new({
    index:  File.read('index.md'), 
    header: File.read('src/header.html'), 
    footer: File.read('src/footer.html'), 
    ** config
  })
  .add(Post.from(reader_fn, 'posts/**.md'))
  .add(Page.from(reader_fn, 'pages/**.md'))
  .compile({ "{{FOO}}" => 'BAR' })
  .each do | page |
    puts "writes: #{page.path}"

    FileUtils.mkdir_p(File.join(config['dest'], page.path.dirname))
    File.write(File.join(config['dest'], page.path), page.contents) 
  end

  FileUtils.cp_r 'public/.', File.join(config['dest'], 'public')  
  
  puts "result: OK"
end 

build YAML.load_file './_config.yml'
