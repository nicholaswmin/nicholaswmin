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
# - An init method
# - Tests
# - Problem
# - Error handling
# - Unique page class
# - Bring RSS back
# - Style tweaks
# - Create `IndexPage` page as class, pass created stuff into the compile 
#   handler. Use them to compile a `<ul>`.
# 
# - use https://rubystyle.guide/#percent-q-shorthand

# --- Classes ---

class Blog
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

    @pages = @pages.map do | page | 
      page.compile({ '{{FAVICON}}' => @favicon, **tokens }) 
    end
        
    @pages
  end

  def add pages
    [pages].flatten.each do | page |
      @pages.push(page.prepend(@header).append(@footer))
    end

    self
  end
  
  def generate_index
    html = Kramdown::Document.new(@index, input: 'GFM')
      .to_html + "<ul class=\"posts\">\n"

    # @todo use reduce & shorthand
    posts.each do | post | 
      open  = "<li><article>"
      head  = "<h3>#{post.title}</h3>"
      date  = "<h4><time datetime='#{post.date}}'>#{post.year}<time></h4>"
      close = "</article></li>\n"

      html << "#{open}<a href='#{post.path}'>#{head}</a>#{date}#{close}" 
    end
  
    html << "</ul>\n"

    add(HTMLPage.new(
      path: 'index.html', 
      html: "#{@header} #{html} #{@footer}"
    ))
    
    self
  end

  attr_reader :config
end

class HTMLPage
  def initialize path:,  html:, title: 'home'
    @path = Pathname.is_a?(Pathname) ? path : Pathname.new(path)
    @title = title ||= @path.basename.to_s
    @data = ''
    @htmls = [html]
  end
  
  def data
    @data
  end
  
  def compile tokens = {}
    compiled = @htmls.reduce :+
    
    @data = { 
      **tokens, "{{TITLE}}" => @title, "{{BYTES}}" => compiled.bytesize.to_s 
    }.reduce compiled do | compiled, (placeholder, value) | 
      compiled = compiled.gsub(placeholder, value.to_s) 
    end

    self
  end
  
  def prepend html  
    @htmls.unshift html
    self
  end
  
  def append html  
    @htmls.push html
    self
  end

  attr_reader :path, :title
end

class MDPage < HTMLPage
  def initialize path:, md:
    super(
      path:,
      title: parse_title(md), 
      html: Kramdown::Document.new(md, input: 'GFM').to_html)
  end
  
  def parse_title md
    md.lines.first&.start_with?('# ') ? 
      md.lines.first[2..-1].strip : 
      'Blog Index'
  end
  
  def self.from dir 
    Pathname.glob(dir).map do | path |
      self.new(path:, md: File.read(path))
    end
  end
end

class Page < MDPage 
  def initialize path:, md: 
    super(path: "#{path.basename(path.extname)}.html", md:)
  end
end

class Post < MDPage
  def initialize path:, md: 
    super(path: "posts/#{path.basename(path.extname)}.html", md:)

    @date = parse_date md
    @year = @date.strftime '%b, %Y'
  end
  
  def parse_date md
    Date.parse(md.lines[2]&.strip || '') rescue Date.today
  end

  attr_reader :date, :year
end

# --- Build function ---- 

def build config
  Blog.new({
    index:  File.read('index.md'), 
    header: File.read('src/header.html'), 
    footer: File.read('src/footer.html'), 
    ** config
  })
  .add(Post.from('posts/**.md') + Page.from('pages/**.md'))
  .compile()
  .each do | page |
    puts "built: #{page.path}"

    FileUtils.mkdir_p(File.join(config['dest'], page.path.dirname))
    File.write(File.join(config['dest'], page.path), page.data) 
  end
  
  FileUtils.cp_r 'public', File.join(config['dest'], 'public')  
end 

build YAML.load_file './_config.yml'
