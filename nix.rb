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

puts "\033[34m\ngems installed and loaded\n\e[0m"

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

# --- Classes ---

class Blog
  def initialize(config, includes)
    @config   = config
    @includes = includes
    @pages = []
  end
  
  def posts 
    @pages.filter { _1.class === "MarkdownPost" }
  end
  
  def compile(tokens = {})
    generate_index
    
    @pages = @pages.map{ | page | page.compile(tokens) }
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
    list = Kramdown::Document.new(@includes[:index], { input: 'GFM'})
      .to_html + "<ul class=\"posts\">\n"

    # @todo use reduce & shorthand
    posts.each { | post | 
      open  = "<li><article>"
      href  = "/#{post.link}"
      head  = "<h3>#{post.title}</h3>"
      date  = "<h4><time datetime='#{post.date}}'>#{post.year}<time></h4>"
      close = "</article></li>\n"

      list << "#{open}<a href='#{href}'>#{head}</a>#{date}#{close}" 
    }
  
    list << "</ul>\n#{@includes[:footer]}"

    "#{@includes[:header]} #{list} #{@includes[:footer]}"

    add_page(HTMLPage.new("/", @config['site_name'], list))
    
    self
  end
  
  def generate_rss()
    # move this away
    rss = RSS::Maker.make("2.0") do |maker|
      maker.channel.author = @config['author_name']
      maker.channel.updated = Time.now.to_s
      maker.channel.title = "#{@config['site_name']} RSS Feed"
      maker.channel.description = "Official RSS Feed for #{@config['site_url']}"
      maker.channel.link = @config['site_url']
      
      posts.each do |post|
        maker.items.new_item do |item|
          item.link = "#{@config['site_url']}/#{@config['output']['posts']}/#{post.link}"
          item.title = post.title
          item.updated = (Date.parse(post.date.to_s).to_time + 12*60*60).to_s
          item.pubDate = date.rfc822
          item.description = post.data
        end
      end
      rss
    end
  end
  
  attr_reader :pages
end


class Blogfile
  def initialize(path, data = nil)
    @dir = File.join(File.dirname(path), File.basename(path, ".*"))
    @path = File.join(@dir, 'index.html')
    @data = data
  end

  attr_reader :dir, :path, :data
end

class CSSFile < Blogfile
  def initialize(path, filename, css)
    super(path, css)

    @path = File.join(path, filename)
  end

  attr_reader :dir, :path, :data
end

class Page < Blogfile
  def initialize(path, title, html)
    super(path)

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
  
  def add_fragment(html, index = nil)  
    @htmls.insert(index ||= @htmls.length, html)

    self
   end
   
   def link_css(path)
     add_fragment('<link rel="stylesheet" href="'+path+'"></link>')
   end
  
  attr_reader :html, :dir
end

class HTMLPage < Page
  def initialize(path, title, html)
    super
  end
  
  attr_reader :dir, :html, :title
end

class MarkdownPage < Page
  def initialize(path, markdown)
    super(path, extract_title(markdown), Kramdown::Document.new(markdown, {
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
  def initialize(path, markdown)
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

def write_page(output_dir, page) 
  path = File.join(output_dir, page[:dir])
  File.write("#{path}/index.html", page[:html])
  
  puts "wrote: #{path}"
end


# @todo guard against unnknown files
def load_dir(path, ext = ['.md']) 
  Find.find(path == '/' ? './' : path)
    .filter { ext.include? File.extname(_1) }
    .map { File.read(_1) }
end

def load_files(hash)
  hash.each do |k, v|
    hash[k] = v.is_a?(String) && File.exist?(v) ? 
      (File.directory?(v) ? load_dir(v) : File.read(v)) : hash[k]
    v.is_a?(Hash) ? load_files(v) : nil
  end
  hash
end

# --- Build function ---- 

def build(config)  
  files = load_files(config['files'])
  header = files['includes']['header']
  footer = files['includes']['footer']
  index  = files['includes']['index']

  blog = Blog.new(config, { header:, footer:, index: })

  posts = files['input']['posts'].map {
    MarkdownPost.new(config['output']['posts'], _1)
      .add_fragment(header, 0)
      .add_fragment(footer)
      .link_css(File.join(config['output']['posts'], 'hl.css'))}
  
  pages = files['input']['pages'].map { 
    MarkdownPage.new(config['output']['posts'], _1)
      .add_fragment(header, 0)
      .add_fragment(footer) }
  
  blog
    .add_pages(pages + posts)
    .compile({ "{{FAVICON}}" => config['favicon']  })
  
  puts blog.pages[3].data
  #puts File.join(config['output']['root'], doclist.posts[0].dir, 'index.html')
  
  # ensure the build dirs exist, create them if not
  # [dirs['output'], dirs['posts_output']].each { |dir| FileUtils.mkdir_p(dir) }
  
  #write_page
end

build(YAML.load_file('_config.yml'))
