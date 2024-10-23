#!/usr/bin/env ruby

# Original code is from "wruby" Bradley Taunt
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

class InvalidFormatException < StandardError
  def message
    "\nPost is incorrectly formatted\n\n" +
    "It must be formatted like so:\n\n" +
    "line 1: # <TITLE>\n" + 
    "line 2: <empty-line>\n" + 
    "line 3: <DATE-YYYY:MM:DD>\n" +
    "line 4: <empty-line >\n" +
    "line 5: content starts ...\n\n" +
    "Example:\n\n" +
    "# My thoughts on FooBar \n" + 
    "\n" + 
    "2022-11-22\n\n" +
    "\n" +
    "Lorem ipsum dolor sit amet bla bla\n" +
    "bla bla bla ....\n\n"
  end
end

# Replace the title meta tag in the header.html
def replace_title(header, title)
  header.gsub('<title>{{TITLE}}</title>', "<title>#{title}</title>")
end


# Replace the bytes placeholder
def replace_bytes(html)
  html.gsub('{{BYTES}}', html.split.join.bytesize.to_s)
end


# Replace the favicon in header.html
def replace_favicon(html, favicon)
  html.gsub('{{FAVICON}}', favicon)
end

# Grab the title from each markdown file
def extract_title_from_md(lines, p)
  first_line = lines.first
  first_line&.start_with?('# ') ? first_line[2..-1].strip : 'Blog Index'
end

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

# render to github-style markdown
def markdown_to_html(md_content)
  Kramdown::Document.new(md_content, {
    input: 'GFM',
    auto_ids: true,
    syntax_highlighter: 'rouge'
  }).to_html
end


# Convert markdown files
def process_md_files(input_dir, header, footer, favicon)
  threads = []
  items = []

  Find.find(input_dir) do |path|
    next unless path =~ /\.md\z/

    threads << Thread.new {
      md_content = File.read(path)
      lines = md_content.lines
  
      title = extract_title_from_md(lines, path)
      date = Date.parse(lines[2]&.strip || '') rescue Date.today
      year = date.strftime("%b, %Y")

      header = replace_title(replace_favicon(header, favicon), title)
      html = replace_bytes(header + markdown_to_html(md_content) + footer)
      path = path.sub(input_dir + '/', '').sub('.md', '')

      items << { 
        title: title, 
        date: date, 
        year: year, 
        link: path + '/', 
        path: path,
        html: html 
      } 
    }
    
    threads.each { |thr| thr.join }
  end

  items
end

def process_pages(input_dir, output_dir, header, footer, favicon) 
  pages = process_md_files(input_dir, header, footer, favicon)
  
  pages.each { | page | 
    html = add_main_css_class(page[:html], 'page') 

    item_dir = File.join(output_dir, page[:path])
    
    FileUtils.mkdir_p(item_dir)
    File.write("#{item_dir}/index.html", html)
  
    puts "\033[1;36m processed page: #{page[:title]}\e[0m"
  }
  
  pages
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

# @todo config for dark or light
def generate_highlight_css(output_dir, public_dir)
  css = Rouge::Themes::Github.mode(:dark).render(scope: '.highlight')
  File.write("#{output_dir}/#{public_dir}/highlight.css", css)
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


# ------------ Build/Serve Functions ------------


def build(config)
  posts_dir = config['directories']['posts']
  pages_dir = config['directories']['pages']
  public_dir = config['directories']['public']
  output_dir = config['directories']['output']
  posts_output_dir = config['directories']['posts_output']
  pages_output_dir = config['directories']['pages_output']
  
  root_index = config['files']['root_index']
  posts_index = config['files']['posts_index']
  header_file = config['files']['header']
  footer_file = config['files']['footer']

  rss_file = config['files']['rss']
  site_url = config['site_url']
  site_name = config['site_name']
  author_name = config['author_name']
  post_count = config['misc']['post_count']
  favicon = config['misc']['favicon']

  [posts_output_dir, pages_output_dir].each { |dir| FileUtils.mkdir_p(dir) }
  
  header = File.read(header_file)
  footer = File.read(footer_file)

  verify_post_format(posts_dir)

  posts  = process_posts(posts_dir, posts_output_dir, public_dir, header, footer, favicon)
    .sort_by { |post| -post[:date].to_time.to_i }
  pages  = process_pages(pages_dir, pages_output_dir, header, footer, favicon)

  generate_highlight_css(output_dir, public_dir)
  generate_index(posts, header, footer, root_index, post_count, output_dir, posts_dir)
  generate_rss(posts, rss_file, author_name, site_name, site_url, posts_dir)

  FileUtils.cp_r(public_dir, output_dir)  
  
  puts "\033[32m\nbuild completed. output: '#{output_dir}/'\n \e[0m"
end


def serve(port, output_dir, public_dir)
  root = File.expand_path "#{output_dir}"

  server = WEBrick::HTTPServer.new :Port => port, :DocumentRoot => root

  server.mount(
    "#{public_dir}", 
    WEBrick::HTTPServlet::FileHandler, 
    "#{output_dir}/#{public_dir}/*"
  )

  trap 'INT' do 
    server.shutdown 
    exit true
  end
  
  puts "\033[1;35m- server starting at: 8000 - \e[0m"

  server.start
end


# ---------------- Program Main -----------------


Thread.abort_on_exception = true

# Load configuration
config = YAML.load_file('_config.yml')

public_dir = config['directories']['public']
output_dir = config['directories']['output']

# Run the build
build(config)

# Dev. extras

threads = []

# Run server
if (['--serve', '-s'] & ARGV).any? 
  threads << Thread.new {
    arg_p_i = ARGV.index('-p') ? ARGV.index('-p') : ARGV.index('--port')
    port = arg_p_i ? ARGV[arg_p_i + 1] : 8000

    serve(port, output_dir, public_dir)
  } 
end
 
# Watch for changes
if (['--watch', '-w'] & ARGV).any? 
  threads << Thread.new {
    puts "\033[1;36m- watching for file changes at: **/*.* ...\e[0m"
    Filewatcher.new('**/*.*', exclude: 'build/').watch do |changes|
      build(config)
    end
  }
end

threads.each { |thr| thr.join }
