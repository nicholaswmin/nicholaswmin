#!/usr/bin/env ruby
class Site
  attr_reader :layouts, :pages

  def initialize layouts = []
    @layouts = layouts.map do |layout| [layout.name, layout] end.to_h 
    @docs = []
  end
  
  def add pages
    @docs = @docs + pages

    self
  end
  
  def pages
    @docs.filter do |doc| doc.is_a?(HTMLPage) end 
  end
  
  def compile variables:
    @docs
      .map do |page| page.compile layouts:, ctx: { pages:, variables: } end
      .flatten.uniq do |page| page.path end
  end
end

class Layout
  attr_reader :name

  def initialize path, html
    @name = path.basename(path.extname).to_s
    @html = html
  end
  
  def to_s() @html end
end

class Document
  attr_reader :path, :name, :data

  def initialize path, data = nil
    @path = Pathname.new path.to_s
    @name = @path.parent.basename.to_s
    @data = data
  end
end

class HTMLPage < Document
  attr_reader :title

  def initialize path:, title:
    super path
    @title = title ||= @path.basename.to_s
  end

  def compile layouts:, ctx:   
    type  = self.class.to_s.downcase
    name  = @path.basename(@path.extname).to_s

    @data = replace (
       <<~BODY
        #{layouts['header']}
          <main class="#{type} #{name}">#{render(ctx)}</main>
         #{layouts['footer']}
        BODY
    ), ctx[:variables]

    self
  end 
  
  def render(*) '' end
  def to_s() @data end

  private def replace html, variables
    { **variables, 
      'title' => @title, 
      'bytes' => html.gsub(/\s+/, '').bytesize.to_s 
    }.reduce html do | html, (variable, value) | 
      html = html.gsub('{{' + variable.to_s + '}}', value.to_s) 
    end
  end
end

# ------- Blog ---------
 
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'optparse', '~> 0.4.0', require: true
  gem 'webrick', '~> 1.8.2', require: true
  gem 'kramdown', '~> 2.4.0', require: true
  gem 'kramdown-parser-gfm', '~> 1.1.0', require: true
  gem 'rouge', '~> 4.4.0', require: true
  gem 'logger', '~> 1.6.0', require: false
end

class MarkdownPage < HTMLPage
  def initialize path, markdown, title = nil
    super(path:, title: title ? title : to_title(markdown))
    @markdown = markdown
  end
  
  def render ctx
    super(ctx) + Kramdown::Document.new(@markdown, {
      input: 'GFM', auto_ids: true,
      syntax_highlighter: 'rouge'
    }).to_html
  end
  
  private def to_title markdown
    markdown.lines.first&.start_with?('# ') ? 
      markdown.lines.first[2..-1].strip : 
      'Untitled'
  end
end

class Page < MarkdownPage 
  def initialize path, markdown
    super "/#{path.basename(path.extname)}/index.html", markdown
  end
end

class Post < MarkdownPage
  attr_reader :date, :link
  
  def initialize path, markdown
    @date = Date.parse(markdown.lines[2]&.strip || '') rescue Date.today
    @link = "/posts/#{path.basename(path.extname)}"
    super "/posts/#{path.basename(path.extname)}/index.html", markdown
  end
  
  def render ctx
    super(ctx) + '<link rel="stylesheet" href="/public/highlight.css"><link>'
  end
end

class Index < MarkdownPage 
  def initialize path, markdown
    super path + '/index.html', markdown, 'Home'
  end

  def render ctx
    ispost = -> item do item.class.to_s == 'Post' end

    super(ctx) + to_list(ctx[:pages].filter(&ispost), -> list, post { 
      list << post = <<~BODY
      <li>
        <a href="#{post.link}">
          <h3>#{post.title}</h3> 
          <div>#{post.date.strftime('%b, %Y')}</div> 
        </a>
      </li>
      BODY
    })
  end

  private def to_list items, to_list_item
    list = <<~BODY.squeeze("\n")
      <ul class="list">
        #{items.reduce('',&to_list_item)}
      </ul>
    BODY
  end
end

# --- Builder ---- 

COLOR = ENV['NO_COLORS'] ? Hash.new('') : { 'ok' => "\e[0;32m", '0' => "\e[0m" }

def build config
  base = config['base']
  dest = config['dest']
  new = -> type do -> path do type.new(path, File.read(path)) end end

  FileUtils.rm_rf(Dir[dest])   

  Site
    .new(Pathname.glob('_layouts/*.html', base:).map(&new[Layout]))
    .add(Pathname.glob('posts/*[^index]*.md', base:).map(&new[Post]))
    .add(Pathname.glob('pages/*[^index].md', base:).map(&new[Page]))
    .add(Pathname.glob('pages/index.md', base:).map(&new[Index]))
    .compile(variables: config) 
    .map do |page| 
      path = Pathname File.join dest, page.path

      FileUtils.mkdir_p path.dirname
      File.write(path, page.data); puts "- wrote: #{path}"   
    end
  
  FileUtils.cp_r(File.join(base, 'public/'), File.join(dest, 'public'))

  puts "#{COLOR['ok']} init:ok, output: #{dest} #{COLOR['0']}"
end

# --- Program Main -----

build YAML.load_file './_config.yml'
