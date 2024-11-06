#!/usr/bin/env ruby
# frozen_string_literal: true

APP_NAME = 'nix'
APP_DESC = 'site generator'

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'date', '~> 3.4.0', require: true
  gem 'optparse', '~> 0.4.0', require: true
  gem 'open-uri', '~> 0.4.1', require: true
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
    @data = replace(html, ctx[:variables].merge({ root_url: root_url }))
    self
  end
  
  def root_url(basename = '')
    File.join(path.each_filename.to_a.drop(1).map { '../' }
      .join(''), basename).delete_prefix('/')
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
    "#{super}<link rel=\"stylesheet\" href=\"#{root_url}highlight.css\">
    <link>"
  end
end

def config = YAML.load_file('_config.yml', symbolize_names: true) 

class Index < MarkdownPage
  def initialize(_path, markdown)
    super('/index.html', markdown, 'Home')
  end
    
  def post? = ->(page) { page.is_a?Post } 
  def posts(ctx) = ctx[:pages].filter(&post?).sort_by(&:date).reverse

  def render(ctx)    
     "%s <ul class=\"list\">%s</ul>" % [super, posts(ctx).reduce(+'') do 
      |list, p| list << "<li>
        <a href=\"/posts/%<name>s\"><h3>%<head>s</h3><small>%<year>s</small></a>
      </li>" % { head: p.title, year: p.date.strftime('%b, %Y'), name: p.name }
    end]
  end
end

def color(name, colors = { 'red': 31, 'yellow': 33, 'green': 32, blue: 34 })
  ENV['NO_COLOR'] || !STDOUT.tty? ? '' : "\e[0;#{colors[name.downcase.to_sym]}m"
end

def writefile(dest, force: false) = 
  lambda do |page|
    FileUtils.mkdir_p(File.dirname(File.join(dest, page.path)))
    if File.exist?(page.path) && !force 
      return 
    end
    File.write(File.join(dest, page.path), page.data)
end

def build(dest:, **variables)
  FileUtils.rm_rf(File.join(dest, '/'))

  Site
    .new(Dir['_layouts/*.html'].map(&Layout.from(File.method(:read))))
    .add(Dir['posts/*.md'].map(&Post.from(File.method(:read))))
    .add(Dir['pages/*[^index]*.md'].map(&Page.from(File.method(:read))))
    .add(Dir['pages/index.md'].map(&Index.from(File.method(:read))))
    .compile(variables:).each(&writefile(dest, force: true))

  FileUtils.cp_r('public/.', dest)
  puts color(:green), 'build: ok', color(:reset)
end
  
def serve(port:, dest:, **)
  exec "ruby -run -e httpd -- #{dest.tr('./', '')} -p #{port ||= 8000} ||= '0'}"
end

def init(url = './init.yml')
  path = File.exist?(File.basename(url)) ? File.basename(url) : URI(url).open
  hash = YAML.load(path.is_a?(URI) ? path.read : File.read(path)).inject(:merge)
  hash.keys.map(&Document.from(hash)).each(&writefile('./', force: true))
  puts color(:green), 'init ok', color(:reset)
end

op = OptionParser.new(nil, 25, 'ruby nix.rb') do |o|
  o.on '--build', 'build static HTML' do |v| build(**config) end
  o.on '--init [url]', 'create site' do _1 ? init(_1) : init() end
  o.on '--serve [port]', 'run server' do serve(**{ port: _1, **config }) end
end

puts ARGV.empty? ? "\n#{op}\ndocs: https://github.com/nicholaswmin/nix\n\n" : ""
op.parse!
