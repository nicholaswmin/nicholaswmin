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
  def initialize(opts)
    @name = opts[:name]
    @url = opts[:name]
    @author = opts[:author]
    @favicon = opts[:favicon]

    @index = opts[:index]
    @header= opts[:header]
    @footer = opts[:footer]

    @pages = []
  end
  
  def posts 
    @pages.filter { _1.class === "MarkdownPost" }
  end
  
  def compile(tokens = {})
    generate_index
    @pages.map{ _1.compile({ '{{FAVICON}}' => @favicon }) }
  end

  def add(pages)
    [pages].flatten.each{ add_page(_1) }

    self
  end

  private
  def add_page(page)
    @pages.push(page.prepend(@header).append(@footer))
  end
  
  def generate_index
    html = Kramdown::Document.new(@index, { input: 'GFM'})
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
  
    html << "</ul>\n"

    "#{@header} #{html} #{@footer}"

    add(HTMLPage.new(path: 'index.html', title: @name, html:))
    
    self
  end
  
  #def generate_rss end #@ todo 
  
  attr_reader :pages
end

class HTMLPage
  def initialize(path:, title:, html:)
    @path = Pathname.is_a?(Pathname) ? path : Pathname.new(path)
    @title = title ||= @path.basename.to_s
    @data  = data
    @htmls = [html]
  end
  
  def compile(tokens = {})
    compiled = @htmls.reduce(:+) 
    @data = ({ "{{TITLE}}" => @title, "{{BYTES}}" => compiled.bytesize.to_s }
      .merge(tokens)).reduce(compiled) { _1.gsub(_2[0], _2[1].to_s) }
  
    self
  end
  
  def prepend(html)  
    @htmls.unshift(html)
    self
  end
  
  def append(html)  
    @htmls.push(html)
    self
  end

  attr_reader :path, :title, :data
end

class MarkdownPage < HTMLPage
  def initialize(path:, markdown:)  
    super(
      path:,
      title: parse_md_title(markdown), 
      html: Kramdown::Document.new(markdown, {
        input: 'GFM', auto_ids: true,
        syntax_highlighter: 'rouge'
      }).to_html)
  end
  
  def parse_md_title(markdown)
    markdown.lines.first&.start_with?('# ') ? 
      markdown.lines.first[2..-1].strip : 
      'Blog Index'
  end
  
  def self.from dir 
    Pathname.glob(dir).map do | path |
      self.new(path:, markdown: File.read(path))
    end
  end
end

class Page < MarkdownPage 
  def initialize(path:, markdown:)  
    super(path: "#{path.basename(path.extname)}.html", markdown:)
  end
end

class Post < MarkdownPage
  def initialize(path:, markdown:)  
    super(path: "posts/#{path.basename(path.extname)}.html", markdown:)

    @date = parse_md_date(markdown)
    @year = @date.strftime('%b, %Y')
  end

  def parse_md_date(markdown)
    Date.parse(markdown.lines[2]&.strip || '') rescue Date.today
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
  .add(Post.from('posts/**.md'))
  .add(Page.from('pages/**.md'))
  .compile
  .each do | page |
    puts "\033[36m- writing: #{page.path}\e[0m"

    FileUtils.mkdir_p(File.join(config['dest'], page.path.dirname))
    File.write(File.join(config['dest'], page.path), page.data) 
  end
  
  FileUtils.cp_r 'public', File.join(config['dest'], 'public')  
end 

build YAML.load_file './_config.yml'
