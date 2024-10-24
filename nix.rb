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

# --- Classes ---

class MarkdownFragment 
  def initialize(markdown_text)
    @markdown_text = markdown_text
  end
  
  def to_title 
    lines = @markdown_text.lines
    lines.first&.start_with?('# ') ? lines.first[2..-1].strip : 'Blog Index'
  end

  def to_html()
    Kramdown::Document.new(@markdown_text, {
      input: 'GFM', auto_ids: true,
      syntax_highlighter: 'rouge'
    })
    .to_html
    .gsub('{{TITLE}}', to_title)
  end
end

class PageList
  # todo header/footer/root turn into a hash 'fragments'
  def initialize(header, footer, root, dirs, config)
    @header = header
    @footer = footer
    @root   = root 

    @dirs   = dirs
    @config = config

    @posts = []
    @pages = []
  end
  
  def add_post(path, markdown_text)
    post = Post.new(path, markdown_text)
      .attach_header(@header)
      .attach_footer(@footer)
      .attach_highlights(@dirs['public'])
      .replace_bytes_placeholder()
      .replace_favicon_placeholder(@config[:favicon])

    @posts.push(post)
    
    self
  end
  
  def add_page(path, markdown_text)
    page = Page.new(path, markdown_text)
      .attach_header(@header)
      .attach_footer(@footer)
      .replace_bytes_placeholder()
      .replace_favicon_placeholder(@config[:favicon])

    @pages.push(page)

    self
  end
  
  def generate_index() 
    list = MarkdownFragment.new(@root).to_html + "<ul class=\"posts\">\n"

    @posts.each { | post | 
      open  = "<li><article>"
      href  = "/#{@dirs['posts']}/#{post.link}"
      head  = "<h3>#{post.title}</h3>"
      date  = "<h4><time datetime='#{post.date}}'>#{post.year}<time></h4>"
      close = "</article></li>\n"

      list << "#{open}<a href='#{href}'>#{head}</a>#{date}#{close}" 
    }
  
    list << "</ul>\n#{@footer}"
    
    # @FIXME
    # Broken (header/footer) still have placeholders.
    # A different class modelling is required here
    "#{@header} #{list} #{@footer}"
  end
  
  def generate_rss()
    rss = RSS::Maker.make("2.0") do |maker|
      maker.channel.author = @config[:author_name]
      maker.channel.updated = Time.now.to_s
      maker.channel.title = "#{@config[:site_name]} RSS Feed"
      maker.channel.description = "Official RSS Feed for #{@config[:site_url]}"
      maker.channel.link = @config[:site_url]
  
      @posts.each do |post|
        maker.items.new_item do |item|
          item.link = "#{@config[:site_url]}/#{@dirs['posts']}/#{post.link}"
          item.title = post.title
          item.updated = (Date.parse(post.date.to_s).to_time + 12*60*60).to_s
          item.pubDate = date.rfc822
          item.description = post.data
        end
      end
      rss
    end
  end
end

class PlainFile
  def initialize(path)
    @dir = to_dir_from_path(path)
  end
  
  def to_disk() 
    { dir: @dir }
  end 
  
  def to_dir_from_path(path)
    File.join(File.dirname(path), File.basename(path, ".*"))
  end
  
  attr_reader :path, :data
end

class Page < PlainFile
  def initialize(path, markdown_text)
    @dir   = to_dir_from_path(path)
    @data  = MarkdownFragment.new(markdown_text).to_html
    @title = MarkdownFragment.new(markdown_text).to_title
  end
  
  def to_disk() 
    { dir: @dir, title: @title, data: @data  }
  end 

  def attach_header(header_html)  
    @data = header_html + @data
    self
   end

  def attach_footer(footer_html)
    @data = @data + footer_html
    self
  end
  
  def replace_bytes_placeholder()
    @data = @data.gsub('{{BYTES}}', @data.split.join.bytesize.to_s)
    
    self
  end
  
  def replace_favicon_placeholder(favicon)
    @data = @data.gsub('{{FAVICON}}', favicon)
    self
  end

  def extract_title_from_md(markdown_text)
    lines = markdown_text.lines
    lines.first&.start_with?('# ') ? lines.first[2..-1].strip : 'Blog Index'
  end
    
  attr_reader :dir, :title, :data, :highlights, :date, :year
end

class Post < Page
  def initialize(path, markdown_text)
    @dir   = to_dir_from_path(path)

    @data  = MarkdownFragment.new(markdown_text).to_html
    @title = MarkdownFragment.new(markdown_text).to_title
    
    @link  = "#{@dir}/"
    @date  = parse_date(markdown_text)
    @year  = @date.strftime("%b, %Y")
    
    @highlights = []
  end
  
  def to_disk() 
    { dir: @dir, title: @title, data: @data, highlights: @highlights  }
  end 
  
  def to_rss()
    { title: @title, date: @date, data: @data }
  end
  
  
  # @todo allow custom
  def attach_highlights(public_dir)
    tag = '<link rel="stylesheet" href="/'+ public_dir +'/highlight.css"><link>'

    highlights.push(Rouge::Themes::Github.mode(:light)
      .render(scope: '.highlight'))
    
    self
  end
  
  def parse_date(markdown_text)
    Date.parse(markdown_text.lines[2]&.strip || '') rescue Date.today
  end

  attr_reader :dir, :link, :title, :fname, :data, :highlights, :date, :year
end

def is_markdown(path) 
  ['.md'].include? File.extname(path)
end

def write_page(output_dir, page) 
  path = File.join(output_dir, page[:dir])
  File.write("#{path}/index.html", page[:data])
  
  puts "wrote: #{path}"
end

def build(config)
  dirs  = config['directories']
  files = config['files']

  # ensure the build dirs exist, create them if not
  [dirs['output'], dirs['posts_output']].each { |dir| FileUtils.mkdir_p(dir) }
  
  # @TODO use the structure of config directly and stop
  # reinitializing stuff
  page_list = PageList.new(
    File.read(config['files']['header']), 
    File.read(config['files']['footer']),
    File.read(config['files']['root_index']),
    dirs, 
    { 
      site_url: config['site_url'], 
      site_name: config['site_name'], 
      author_name: config['author_name'],
      favicon: config['misc']['favicon']
    }
  )

  posts = Find.find(dirs['posts'])
    .filter { | path | is_markdown(path) }
    .map    { | path | page_list.add_post(path, File.read(path)) }

  posts = Find.find(dirs['pages'])
    .filter { | path | is_markdown(path) }
    .map    { | path | page_list.add_page(path, File.read(path)) }
  
  puts page_list.generate_index
end

build(YAML.load_file('_config.yml'))
