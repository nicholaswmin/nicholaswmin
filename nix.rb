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
# 
# --- Classes ---

# The main class. It holds all `Page`-like instances.
# 
# - When `compile` is called it compiles every page
#   and returns a list of `Files`-like instances,
#   which is the blog pages plus any deduped assets.

class Site
  def initialize config:
    @config = config.clone
    @layouts = []
    @pages = []
  end

  def posts 
    @pages.filter do | page | page.class.to_s.downcase.include? 'post' end
  end
  
  def use layouts
    @layouts = (layouts.map do | layout | [layout.name, layout] end).to_h

    self
  end
  
  def compile variables: {}
    pages = @pages.map do | page | page.compile(
      layouts: @layouts, 
      ctx: { posts:, variables: }
    ) 
    end + @pages.map(&:assets).flatten.uniq do | page | page.path end
  end

  def add pages
    [pages].flatten.each do | page | @pages.push page end

    self
  end
  
  def self.from_entry
    Proc.new do | entry | self.new path: entry[0], html: entry[1] end
  end
end

class Layout 
  attr_reader :name

  def initialize path:, html:
    @name = path.basename(path.extname).to_s
    @html = html
  end
  
  def self.from_entry
    Proc.new do | entry | self.new path: entry[0], html: entry[1] end
  end
  
  def to_s
    @html
  end
end

class Asset 
  attr_reader :path, :contents
  
  def initialize filename:, contents:
    @path = Pathname.new("/public/#{filename.split('/').last}")
    @contents = contents
  end
end

class HTMLPage
  attr_reader :path, :title, :assets, :contents

  def initialize path:, title:, assets: []
    @path = Pathname.new(path.to_s)
    @title = title ||= @path.basename.to_s
    @assets = []
    @contents = nil
    
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

    @contents = replace html, ctx[:variables]
    
    self
  end
  
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
  
  private def to_html () raise StandardError.new 'abstract class' end
end

# --- Userland (supposedly) ---- 

class CSS < Asset 
  def to_str
    format('<link rel="stylesheet" href="%<path>s"></link>', path:)
  end
end

# @TODO this feels wrong?
class MarkdownPage < HTMLPage
  def initialize path:, title: nil, markdown: 
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
  
  def self.from_entry
    Proc.new do | entry | self.new path: entry[0], markdown: entry[1] end
  end
end

class Page < MarkdownPage 
  def initialize path:, markdown: 
    super path: "/#{path.basename(path.extname)}/index.html", markdown:
  end
end

class Post < MarkdownPage
  attr_reader :date, :link
  
  def initialize path:, markdown:
    super(path: "/posts/#{path.basename(path.extname)}/index.html", markdown:)

    @date = Date.parse(markdown.lines[2]&.strip || '') rescue Date.today
    @link = @path.dirname
  end
  
  def assets
    CSS.new(
      filename: 'highlight.css', 
      contents: Rouge::Themes::Github.mode(:light)
        .render(scope: '.highlight') 
    )
  end
end

class Index < MarkdownPage 
  def initialize path:, markdown:
    super(path: '/index.html', title: 'Home', markdown:)
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


module Builder  
  def run
    puts "\033[1;34m- start: OK - \e[0m"
    config = YAML.load_file './_config.yml'

    build(dest: config['dest'], config:)
    puts "\033[1;32m- build: OK - \e[0m"
    
    serve port: 8081, dest: config['dest'].sub('./', '')
  end
  
  def build dest:, config: 
    Site.new(config:)
      .use(read('_layouts/*.html').map(&Layout.from_entry))
      .add(
        read('posts/*.md').map(&Post.from_entry) +
        read('pages/*[^index]*.md').map(&Page.from_entry)  +
        read('pages/index.md').map(&Index.from_entry)
      )
      .compile(variables: config)
      .each(&write(dest))
  
    FileUtils.cp_r('public/.', 'build/public/')
  end
  
  # --- File helpers ---- 
  
  def write dest 
    -> page { 
      dirpath = File.join dest, page.path.dirname
      filepath = File.join dest, page.path 

      FileUtils.mkdir_p dirpath
      File.write filepath, page.contents  

      puts "- wrote: #{page.path}"  
    }
  end

  def read glob 
    Dir[glob].map { | path | [Pathname(path), File.read(path)] }
  end
  
  # --- Server (@todo temp only, remove it) ---- 

  def serve port:, dest:
    server = WEBrick::HTTPServer.new :Port => port, :DocumentRoot => dest
    server.mount 'public', WEBrick::HTTPServlet::FileHandler, "#{dest}/public/"
  
    trap 'INT' do server.shutdown exit true end
  
    server.start
  end
end


# --- Main -----


include Builder

run
