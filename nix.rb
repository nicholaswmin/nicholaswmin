#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'date', '~> 3.4.0', require: true
  gem 'kramdown', '~> 2.4.0', require: true
  gem 'kramdown-parser-gfm', '~> 1.1.0', require: true
  gem 'rouge', '~> 4.4.0', require: true
end

class Site
  attr_reader :pages, :layouts

  def initialize(layouts = [])
    @layouts = layouts.to_h { |layout| [layout.name, layout] }
    @pages = []
  end

  def add(new_pages)
    @pages += new_pages
    self
  end

  def compile(variables:)
    @pages.map do |page| 
      page.compile(layouts:, ctx: { pages:, variables: })
    end.flatten.uniq(&:path)
  end  
end

class Document
  attr_reader :path, :name, :data

  def initialize(path, data = nil, name = nil)
    @path = Pathname.new path.to_s
    @name = name ||= @path.parent.basename.to_s
    @data = data
  end

  def self.from(reader) = ->(path) { new(Pathname.new(path), reader[path]) }
end

class Layout < Document
  def initialize(path, html)
    super(path, html, path.basename(path.extname).to_s)
  end
  def to_s = @data
end

class HTMLPage < Document
  def initialize(path:, title:)
    super(path)
    @title = title || @path.basename.to_s
  end

  def compile(layouts:, ctx:)
    type = self.class.to_s.downcase
    name = @path.basename(@path.extname).to_s
    html = <<~BODY
      #{layouts['header']}
        <main class="#{type} #{name}">#{render(ctx)}</main>
      #{layouts['footer']}
    BODY
    @data = replace(html, ctx[:variables])
    self
  end

  def render(*) = ''

  private def bytesize(html) = html.gsub(/\s+/, '').bytesize.to_s
  private def replace(html, variables)
    { **variables, 'title' => @title, 'bytes' => bytesize(html) }
      .reduce(html) do |replaced, (variable, value)|
      replaced.gsub("{{#{variable}}}", value.to_s)
    end
  end
end

class MarkdownPage < HTMLPage
  attr_reader :title

  def initialize(path, markdown, title = nil)
    super(path:, title: title || markdown.lines.first[2..].strip)
    @markdown = markdown
  end

  def render(ctx)
    super + Kramdown::Document.new(@markdown, { input: 'GFM' }).to_html
  end
end

class Page < MarkdownPage
  def initialize(path, markdown)
    super("/#{path.basename(path.extname)}/index.html", markdown)
  end
end

class Post < MarkdownPage
  attr_reader :date

  def initialize(path, markdown)
    super("/posts/#{path.basename(path.extname)}/index.html", markdown)
    @date = Date.parse(markdown.lines[2]&.strip || '')
  end

  def render(ctx)
    "#{super}<link rel=\"stylesheet\" href=\"/public/highlight.css\"><link>"
  end
end

class Index < MarkdownPage
  def initialize(_path, markdown)
    super('/index.html', markdown, 'Home')
  end
    
  def is_post = ->(page) { page.is_a?Post } 
  def posts(ctx) = ctx[:pages].filter(&is_post).sort_by(&:date).reverse

  def render(ctx)    
    super + "<ul class=\"list\">%s</ul>" % posts(ctx).reduce(+'') do 
      |list, post| list << <<~BODY
        <li>
          <a href="/posts/#{post.name}">
            <h3>#{post.title}</h3>
            <small>#{post.date.strftime('%b, %Y')}</small>
          </a>
        </li>
      BODY
    end
  end
end

def build(dest, config)
  rmrf_dir(dest)

  Site
    .new(Dir['_layouts/*.html'].map(&Layout.from(File.method(:read))))
    .add(Dir['posts/*.md'].map(&Post.from(File.method(:read))))
    .add(Dir['pages/*[^index]*.md'].map(&Page.from(File.method(:read))))
    .add(Dir['pages/index.md'].map(&Index.from(File.method(:read))))
    .compile(variables: config)
    .each(&write_p(dest))

  copy_dir('public/', to: dest)
end

def copy_dir(dir, to:) = FileUtils.cp_r(dir, File.join(to, dir))
def rmrf_dir(dir) = FileUtils.rm_rf(File.join(dir, '/'))
def write_p(dest) = 
  lambda do |page|
    FileUtils.mkdir_p(File.dirname(File.join(dest, page.path)))
    File.write(File.join(dest, page.path), page.data)
end

config = YAML.load_file('_config.yml', symbolize_names: true)
build(config[:dest], config)
puts 'build ok'
exec "ruby -run -e httpd -- #{config[:dest].sub('./', '')} -p 8081 ||= '0'}"
