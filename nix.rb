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
  gem 'rss', '~> 0.3.1', require: true

  gem 'logger', '~> 1.6.0', require: false
end

require 'fileutils'
require 'date'
require 'find'
require 'yaml'

puts "\033[32m- gems installed & loaded!\e[0m"

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
# 
# # Style tweaks
# - use https://rubystyle.guide/#percent-q-shorthand

# --- Classes ---

class Blog
  def initialize(config, includes)
    @config   = config
    @includes = includes
    @files = []
    @pages = []
  end
  
  def posts 
    @pages.filter { _1.class === "MarkdownPost" }
  end
  
  def compile(tokens = {})
    generate_index
    
    @files = @files + @pages.map{ | page | page.compile(tokens) }
  end
  
  def add_file(file)
    @files.push(file)

    self
  end

  def add_pages(pages)
    @pages = @pages + pages

    self
  end

  def add_page(page)
    @pages.push(page)
    self
  end
  
  def generate_index
    html = Kramdown::Document.new(@includes[:index], { input: 'GFM'})
      .to_html + "<ul class=\"posts\">\n"

    # @todo use reduce & shorthand
    posts.each { | post | 
      open  = "<li><article>"
      href  = "/#{post.link}"
      head  = "<h3>#{post.title}</h3>"
      date  = "<h4><time datetime='#{post.date}}'>#{post.year}<time></h4>"
      close = "</article></li>\n"

      html << "#{open}<a href='#{href}'>#{head}</a>#{date}#{close}" 
    }
  
    html << "</ul>\n#{@includes[:footer]}"

    "#{@includes[:header]} #{html} #{@includes[:footer]}"

    add_page(HTMLPage.new(path: '/', title: @config['site_name'], html: ))
    
    self
  end
  
  def generate_rss()
    # move this away
    rss = RSS::Maker.make("2.0") do |maker|
      maker.channel.author = @config["author_name"]
      maker.channel.updated = Time.now.to_s
      maker.channel.title = "#{@config["site_name"]} RSS Feed"
      maker.channel.description = "Official RSS Feed for #{@config["site_url"]}"
      maker.channel.link = @config["site_url"]
      
      posts.each do |post|
        maker.items.new_item do |item|
          item.link = "#{@config["site_url"]}/#{@config["output"]["posts"]}/#{post.link}"
          item.title = post.title
          item.updated = (Date.parse(post.date.to_s).to_time + 12*60*60).to_s
          item.pubDate = date.rfc822
          item.description = post.data
        end
      end
      rss
    end
  end
  
  attr_reader :files
end


class Blogfile
  def initialize(path:, data:)
    @dir = File.join(File.dirname(path), File.basename(path, ".*"))
    @path = File.join(@dir, 'index.html')
    @data = data
  end

  attr_reader :dir, :path, :data
end

class Page < Blogfile
  def initialize(path:, title:, html:)
    super(path:, data: html)

    @title = title
    @htmls = [html]
  end
  
  def compile(tokens = {})
    compiled = @htmls.reduce(:+) 

    @data = ({ "{{TITLE}}" => @title, "{{BYTES}}" => compiled.bytesize.to_s }
    .merge(tokens))
    .reduce(compiled) { _1.gsub(_2[0], _2[1]) }
  
    self
  end
  
  def add_fragment(html:, index: 0)  
    @htmls.insert(index ||= @htmls.length, html)

    self
   end
  
  attr_reader :html, :dir
end

class HTMLPage < Page
  def initialize(path:, title:, html:)
    super
  end
  
  attr_reader :dir, :html, :title
end

class MarkdownPage < Page
  def initialize(path:, markdown:)
    super(path:, title: extract_title(markdown), html: Kramdown::Document.new(markdown, {
      input: 'GFM', auto_ids: true,
      syntax_highlighter: 'rouge'
    }).to_html)
  end
  
  def extract_title(markdown)
    lines = markdown.lines
    lines.first&.start_with?('# ') ? lines.first[2..-1].strip : 'Blog Index'
  end

  attr_reader :dir, :html, :title
end

class MarkdownPost < MarkdownPage
  def initialize(path:, markdown:)
    super
    @date = parse_date(markdown)
    @year = @date.strftime("%b, %Y")
  end

  def parse_date(markdown_text)
    Date.parse(markdown_text.lines[2]&.strip || '') rescue Date.today
  end

  attr_reader :dir, :html, :title, :link, :fname, :date, :year
end

# --- Filesystem helpers ---- 

def load_file(path) 
  { path:, data: File.read(path) }
end

# @todo guard against unnknown files
def load_dir(path, allowed = ['.md', '.html']) 
  Find.find(path == '/' ? './' : path)
    .filter { allowed.include? File.extname(_1) }
    .map { load_file(_1) }
end

def load_files(hash)
  hash.each do |k, v|
    hash[k] = v.is_a?(String) && File.exist?(v) ? 
      (File.directory?(v) ? load_dir(v) : load_file(v)) : hash[k]
    v.is_a?(Hash) ? load_files(v) : nil
  end
  hash
end

def write_blog(blog, dirs)
  # ensure the build dirs exist, create them if not
  puts "\033[36m- rebuilding dirs ...\e[0m"
  [dirs['root'], dirs['posts']].each { FileUtils.mkdir_p(_1) }
  # create the folder and write
  blog.files.each { | file | 
    puts "\033[36m- writing: #{file.dir} ...\e[0m"

    FileUtils.mkdir_p(File.join(dirs['root'], file.dir))
    File.write(File.join(dirs['root'], file.path), file.data) 
  }
  puts "\033[32m ok!\e[0m"
end

# --- Build function ---- 

def build(config)  
  files = load_files(config['files'])
  header = files['includes']['header']
  footer = files['includes']['footer']
  index  = files['includes']['index']
  
  blog = Blog.new(config, { 
    header: header[:data], 
    footer: footer[:data], 
    index:  index[:data] 
  })

  posts = files['input']['posts'].map {
    MarkdownPost.new(path: _1[:path], markdown: _1[:data])
      .add_fragment(html: header[:data], index: 0)
      .add_fragment(html: footer[:data])
  }
  
  pages = files['input']['pages'].map { 
    MarkdownPage.new(path: _1[:path], markdown: _1[:data])
      .add_fragment(html: header[:data], index: 0)
      .add_fragment(html: footer[:data])
  }
  
  blog
    .add_pages(pages + posts)
    .compile({ "{{FAVICON}}" => config['favicon']  })
  
  write_blog(blog, config['output'])
end

build(YAML.load_file('_config.yml'))
