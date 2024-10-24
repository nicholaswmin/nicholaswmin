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
# - Warning (turn on verbose)
# - Tests
# - Problemd
#  - the page index.html is not markdown
#  - current classes are `MarkdownPage` and `MarkdownPost`
#  - I want to have [`MarkdownPage`, `MarkdownPost`, `index.html`] in
#    and treat them all the same: `all.map(c => c.compile())`

# --- Classes ---

class HTMLFragment 
  def initialize(html)
    @html = html
  end
  
  def compile(tokens)
    tokens.reduce(@html) { _1.gsub(_2[0], _2[1]) }
  end
end

class MarkdownFragment 
  def initialize(markdown)
    @markdown = markdown
  end
  
  def to_title 
    lines = @markdown.lines
    lines.first&.start_with?('# ') ? lines.first[2..-1].strip : 'Blog Index'
  end

  def compile()
    HTMLFragment.new(Kramdown::Document.new(@markdown, {
      input: 'GFM', auto_ids: true,
      syntax_highlighter: 'rouge'
    }).compile({ 'title' => to_title }))
  end
end

class DocumentList
  def initialize(config, includes)
    @config   = config
    @includes = includes
    @posts = []
    @pages = []
  end
  
  def add_post(path, markdown_text)
    @posts.push(MarkdownPost.new(path, markdown_text)
      .add_header(@includes['header'])
      .add_footer(@includes['footer'])
      .add_styles(@config['output']['public']))
    self
  end
  
  def add_page(path, markdown_text)
    @pages.push(MarkdownPage.new(path, markdown_text)
      .add_header(@includes['header'])
      .add_footer(@includes['footer']))

    self
  end
  
  def generate_index() 
    list = MarkdownFragment.new(@includes['index'])
      .compile({ "title" => @config['site_name' ]}) + "<ul class=\"posts\">\n"
    
    # use reduce & shorthand
    @posts.each { | post | 
      open  = "<li><article>"
      href  = "/#{post.link}"
      head  = "<h3>#{post.title}</h3>"
      date  = "<h4><time datetime='#{post.date}}'>#{post.year}<time></h4>"
      close = "</article></li>\n"

      list << "#{open}<a href='#{href}'>#{head}</a>#{date}#{close}" 
    }
  
    list << "</ul>\n#{@includes['footer']}"
    
    # @FIXME
    # Broken (header/footer) still have placeholders.
    # A different class modelling is required here
    "#{@includes['header']} #{list} #{@includes['footer']}"
  end
  
  def generate_rss()
    # todo use reduce
    rss = RSS::Maker.make("2.0") do |maker|
      maker.channel.author = @config['author_name']
      maker.channel.updated = Time.now.to_s
      maker.channel.title = "#{@config['site_name']} RSS Feed"
      maker.channel.description = "Official RSS Feed for #{@config['site_url']}"
      maker.channel.link = @config['site_url']
      
      @posts.each do |post|
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
  
  attr_reader :posts, :pages
end


class MarkdownPage
  def initialize(path, markdown_text)
    @dir    = to_dir_from_path(path)
    @data   = MarkdownFragment.new(markdown_text)
    @title  = nil
    @header = nil
    @footer = nil
  end

  def add_header(html)  
    @header = HTMLFragment.new(html)

    self
   end

  def add_footer(html)
    @footer = HTMLFragment.new(html)

    self
  end
  
  def to_dir_from_path(path)
    File.join(File.dirname(path), File.basename(path, ".*"))
  end
    
  attr_reader :dir, :title, :data
end

class MarkdownPost < MarkdownPage
  def initialize(path, markdown_text)
    super

    @styles = []
    @date   = parse_date(markdown_text)
    @year   = @date.strftime("%b, %Y")
  end
  
  
  # @todo allow custom
  def add_styles(path)
    @styles.push({
      css: Rouge::Themes::Github.mode(:light).render(scope: '.highlight'),
      path: path
    })
    
    self
  end
  
  def parse_date(markdown_text)
    Date.parse(markdown_text.lines[2]&.strip || '') rescue Date.today
  end

  attr_reader :dir, :link, :title, :fname, :data, :styles, :date, :year
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
  doclist = DocumentList.new(
    config, 
    config['includes'].transform_values{ File.read(_1) } 
  )

  Find.find(config['input']['posts'])
    .filter { is_markdown(_1) }
    .each   { doclist.add_post(_1, File.read(_1))  }

  Find.find(config['input']['pages'])
    .filter { is_markdown(_1) }
    .each   { doclist.add_page(_1, File.read(_1))  }
  
  puts doclist.posts[0].styles
  puts File.join(config['output']['root'], doclist.posts[0].dir, 'index.html')
  
  # ensure the build dirs exist, create them if not
  # [dirs['output'], dirs['posts_output']].each { |dir| FileUtils.mkdir_p(dir) }
end

build(YAML.load_file('_config.yml'))
