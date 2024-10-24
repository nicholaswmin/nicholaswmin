#!/usr/bin/env ruby

# Original code is from "wruby" by Bradley Taunt
# 
# The MIT License
# 
# Bradley Taunt
#
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the “Software”), to deal 
# in the Software without restriction, including without limitation the rights 
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be 
# included in all copies or substantial portions of the Software.

# ----------------- Dependencies ----------------

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'kramdown', '~> 2.4.0', require: true
  gem 'kramdown-parser-gfm', '~> 1.1.0', require: true
  gem 'rouge', '~> 4.4.0', require: true
  gem 'rss', '~> 0.3.1', require: true

  gem 'webrick', '~> 1.8.2', require: true
  gem 'filewatcher', '~> 2.1.0', require: true
  gem 'logger', '~> 1.6.0', require: false
end

require 'fileutils'
require 'date'
require 'find'
require 'yaml'

puts "\033[34m\ngems installed and loaded\n\e[0m"


# ------------- Content Functions ---------------

def add_main_css_class(html, css_class)
  html.insert(html.index('<main>') + 5, ' class="' + css_class + '"')
end

def verify_post_format (input_dir) 
  Find.find(input_dir) do |path|
    next unless path =~ /\.md\z/
    
    err_f = ", at file: #{path}"
    md_content = File.read(path)

    if (!md_content.lines[0].start_with?("# "))
      STDERR.puts "\033[1;33mWarn: 1st line must be: # <Title>\e[0m#{err_f}\n"
    end

    if (! md_content.lines[1].split.join.empty?)
      STDERR.puts "\033[1;33mWarn: 2nd line must be empty\e[0m#{err_f}\n"
    end
    
    if (! md_content.lines[2].split.join.empty?)
      STDERR.puts "\033[1;33mWarn: 3rd line needs a date\e[0m#{err_f}\n"
    end
  end
end

def process_posts(input_dir, output_dir, pub_dir, header, footer, favicon)
  posts = process_md_files(input_dir, header, footer, favicon)
  
  posts.each { | post |  
    html = post[:html]
    html = add_main_css_class(html, 'post') 
    html += '<link rel="stylesheet" href="/'+ pub_dir + '/highlight.css"><link>'

    item_dir = File.join(output_dir, post.fetch(:path) )

    FileUtils.mkdir_p(item_dir)
    File.write("#{item_dir}/index.html", html)
    
    puts "\033[1;36m processed post: #{post[:title]}\e[0m"
  }
    
  posts
end

# Create the root index file
def generate_index(posts, header, footer, root_index, post_count, output_dir, posts_dir)
  root_index = File.read(root_index)
  title = extract_title_from_md(root_index.lines, root_index)

  md_html  = Kramdown::Document.new(root_index).to_html 
  ul_html = replace_title(header, title) + md_html + "<ul class=\"posts\">\n"

  posts.each { |post| 
    open = '<li><article>'
    close = '</article></li>'

    title = "<h3>#{post[:title]}</h3>"
    date = "<h4><time datetime='#{post[:date]}'>#{post[:year]}<time></h4>"
    url = "/#{posts_dir}/#{post[:link]}"

    ul_html << "#{open}<a href='#{url}'>#{title}</a>#{date}#{close}\n" 
  }

  ul_html << "</ul>\n" + footer

  File.write("#{output_dir}/index.html", replace_bytes(ul_html))
end

# Generate the RSS 2.0 feed
def generate_rss(posts, rss_file, author_name, site_name, site_url, posts_dir)
  rss = RSS::Maker.make("2.0") do |maker|
    maker.channel.author = author_name
    maker.channel.updated = Time.now.to_s
    maker.channel.title = "#{site_name} RSS Feed"
    maker.channel.description = "The official RSS Feed for #{site_url}"
    maker.channel.link = site_url

    posts.each do |post|
      date = Date.parse(post[:date].to_s).to_time + 12*60*60
      item_link = "#{site_url}/#{posts_dir}/#{post[:link]}"
      item_title = post[:title]
      item_content = post[:content]

      maker.items.new_item do |item|
        item.link = item_link
        item.title = item_title
        item.updated = date.to_s
        item.pubDate = date.rfc822
        item.description = item_content
      end
    end
  end

  File.write(rss_file, rss)
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
  def initialize(path, marktext)
    @dir   = to_dir_from_path(path)
    @data  = markdown_to_html(marktext)
    @title = extract_title_from_md(marktext.lines)
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

  def replace_title_placeholder()
    @data = @data.gsub('{{TITLE}}', title)
    
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
  
  def markdown_to_html(marktext)
    Kramdown::Document.new(marktext, {
      input: 'GFM', auto_ids: true,
      syntax_highlighter: 'rouge'
    }).to_html
  end

  def extract_title_from_md(lines)
    lines.first&.start_with?('# ') ? lines.first[2..-1].strip : 'Blog Index'
  end
    
  attr_reader :dir, :title, :data, :highlights, :date, :year
end

class Post < Page
  def initialize(path, marktext)
    @dir  = to_dir_from_path(path)
    @title = extract_title_from_md(marktext.lines)
    @data  = markdown_to_html(marktext)
    @date  = parse_date(data.lines)
    @year  = @date.strftime("%b, %Y")
    
    @highlights = []
  end
  
  def to_disk() 
    { dir: @dir, title: @title, data: @data, highlights: @highlights  }
  end 
  
  def attach_highlights(public_dir)
    tag = '<link rel="stylesheet" href="/' + public_dir + '/highlight.css"><link>'
    
    @data = @data + tag + "\n"

    Rouge::Themes::Github.mode(:light).render(scope: '.highlight')
    
    self
  end
  
  def parse_date(data)
    Date.parse(marktext.lines[2]&.strip || '') rescue Date.today
  end
  
  attr_reader :dir, :fname, :data, :highlights, :date, :year
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
  misc  = config['misc'] 
  
  header = File.read(files['header'])
  footer = File.read(files['footer'])

  #site_url = config['site_url']
  #site_name = config['site_name']
  #author_name = config['author_name']
  
  # ensure the build dirs exist, create them if not
  [dirs['output'], dirs['posts_output']].each { |dir| FileUtils.mkdir_p(dir) }
  
  posts = Find.find(dirs['posts'])
    .filter { | path | is_markdown(path) }
    .map    { | path | Post.new(path, File.read(path)) }
    .map    { | post | post.attach_header(header) }
    .map    { | post | post.attach_footer(footer) }
    .map    { | post | post.attach_highlights(dirs['public']) }
    .map    { | post | post.replace_title_placeholder() }
    .map    { | post | post.replace_bytes_placeholder() }
    .map    { | post | post.replace_favicon_placeholder(misc['favicon']) }
    .map    { | post | write_page(dirs['output'], post.to_disk()) }

  pages = Find.find(dirs['pages'])
    .filter { | path | is_markdown(path) }
    .map    { | path | Page.new(path, File.read(path)) }
    .map    { | page | page.attach_header(header) }
    .map    { | page | page.attach_footer(footer) }
    .map    { | page | page.replace_title_placeholder() }
    .map    { | page | page.replace_bytes_placeholder() }
    .map    { | page | page.replace_favicon_placeholder(misc['favicon']) }
    .map    { | page | write_page(dirs['output'], page.to_disk()) }
end

build(YAML.load_file('_config.yml'))
