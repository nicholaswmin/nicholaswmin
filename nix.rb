#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'webrick', '~> 1.9.0', require: true
  gem 'optparse', '~> 0.4.0', require: true
  gem 'open-uri', '~> 0.4.1', require: true
  gem 'logger', '~> 1.6.0', require: true
  gem 'kramdown', '~> 2.4.0', require: true
  gem 'kramdown-parser-gfm', '~> 1.1.0', require: true
  gem 'rouge', '~> 4.4.0', require: true
end

class Site
  attr_reader :layouts, :variables

  def initialize(layouts = [])
    @variables = nil
    @layouts = layouts.to_h { |layout| [layout.name, layout] }
    @docs = []
  end

  def add(pages)
    @docs += pages
    self
  end

  def pages
    @docs.filter { |doc| doc.is_a?(HTMLPage) }
  end

  def compile(variables:)
    @variables = variables
    @docs
      .map(&compile_page)
      .flatten
      .uniq(&:path)
  end

  def compile_page
    lambda do |page|
      page.compile layouts:, ctx: { pages:, variables: }
    end
  end
end

class Layout
  attr_reader :name

  def initialize(path, html)
    @name = path.basename(path.extname).to_s
    @html = html
  end

  def to_s = @html
   #TODO fix dupe. readable/notwritable, review relation with Document
  def self.from(read) = ->(path) { new(path, read[path]) }
end

class Document
  attr_reader :path, :name, :data

  def initialize(path, data = nil)
    @path = Pathname.new path.to_s
    @name = @path.parent.basename.to_s
    @data = data
  end

  def self.from(read) = ->(path) { new(path, read[path]) }
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
  def to_s = @data

  private

  def replace(html, variables)
    {
      **variables,
      'title' => @title,
      'bytes' => html.gsub(/\s+/, '').bytesize.to_s
    }
      .reduce(html) do |replaced, (variable, value)|
      replaced.gsub("{{#{variable}}}", value.to_s)
    end
  end
end

class MarkdownPage < HTMLPage
  attr_reader :title

  def initialize(path, markdown, title = nil)
    super(path:, title: title || to_title(markdown))
    @markdown = markdown
  end

  def render(ctx)
    super +
      Kramdown::Document
      .new(@markdown, { input: 'GFM', syntax_highlighter: 'rouge' })
      .to_html
  end

  private

  def to_title(mdn)
    mdn.lines.first&.start_with?('# ') ? mdn.lines.first[2..].strip : 'untitled'
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
    @date = begin
      Date.parse(markdown.lines[2]&.strip || '')
    rescue StandardError
      Date.today
    end
  end

  def render(ctx)
    "#{super}<link rel=\"stylesheet\" href=\"/public/highlight.css\"><link>"
  end
end

class Index < MarkdownPage
  def initialize(_path, markdown)
    super('/index.html', markdown, 'Home')
  end

  def render(ctx)
    posts = ctx[:pages].filter { |page| page.instance_of?(::Post) }
    list_items = posts.sort_by(&:date).reverse.reduce(+'') do |list, post|
      list << <<~BODY
        <li>
          <a href="/posts/#{post.name}">
            <h3>#{post.title}</h3>#{' '}
            <small>#{post.date.strftime('%b, %Y')}</small>#{' '}
          </a>
        </li>
      BODY
    end

    super + <<~BODY.squeeze("\n")
      <ul class="list">
        #{list_items}
      </ul>
    BODY
  end
end

$PROGRAM_NAME = 'nix'

Log = Logger.new(
  $stdout,
  level: ENV.fetch('LOG_LEVEL', 'DEBUG'), #FIXME not filtering
  formatter: proc { |severity, _datetime, _progname, msg|
    colored = "#{Color.new(severity)}#{severity} #{msg}#{Color.new}"
    puts severity == 'FATAL' ? puts(msg) && raise(msg) : colored
  }
)

class Color
  @@palette = { fatal: 31, error: 31, warn: 33, info: 32, reset: nil }
  def self.new(severity = '', enabled = !ENV['NO_COLOR'] && $stdout.tty?)
    enabled ? "\e[#{@@palette[severity.downcase.to_sym] || 0}m" : ''
  end
end

class ActionableError < StandardError
  def initialize(msg, action: nil)
    super(<<~BODY)
      #{Color.new(:error)}\n#{msg}#{Color.new}\n
      #{Color.new(:warn)}#{action}#{Color.new}\n
    BODY
  end
end

def glob(...) = Pathname.glob(...) 

def write(base:, force: false)
  lambda do |document|
    path = Pathname.new(base + document.path.to_s) #FIXME brittle, just concats

    FileUtils.mkdir_p path.dirname
    done = File.exist?(path) && !force ? false : File.write(path, document.data)
    done ? Log.debug("wrote #{path}") : Log.warn("skipped #{path}. exists")
  end
end

def init(url:)
  path = File.exist?(File.basename(url)) ? File.basename(url) : URI(url)
  hash = YAML.load(path.is_a?(URI) ? path.read : File.read(path)).inject(:merge)
  hash.keys.map(&Document.from(hash)).each(&write(base: './'))
end

def build(base:, dest:, variables:)
  FileUtils.rm_rf(glob("#{dest}/*", base:))
  Site
    .new(glob('_layouts/*.html', base:).map(&Layout.from(File.method(:read))))
    .add(glob('posts/*[^index]*.md', base:).map(&Post.from(File.method(:read))))
    .add(glob('pages/*[^index]*.md', base:).map(&Page.from(File.method(:read))))
    .add(glob('pages/index.md', base:).map(&Index.from(File.method(:read))))
    .compile(variables:)
    .each(&write(base: dest, force: true))

  FileUtils.cp_r(File.join(base, 'public/'), File.join(dest, 'public'))
end

params = {}
opts = OptionParser.new do |o|
  o.on('-i', '--init',  'create new sample site')
  o.on('-b', '--build', 'build HTML to output')
  o.on('-s', '--serve [PORT]', 'build & serve site at port', Integer)
  o.on('-h', '--help', 'print this help')
end 
opts.parse!(into: params)

if params.key?(:help) || params.empty?
  exit if puts "\n", "https://github.com/nicholaswmin/nix\n\n", opts.help, "\n"
end

if params.key?(:init)
  init(url: 'https://raw.githubusercontent.com/nicholaswmin/nix/main/init.yml')
  Log.info 'init ok'
end

config = begin
   YAML.load_file '_config.yml'
rescue StandardError
  raise Log.fatal ActionableError.new(
    'missing _config.yml',
    action: "If you didnt create a site yet, run:\n\n$ ruby nix.rb --init"
  )
end

if params.key?(:build) || params.key?(:serve)
  build base: config['base'], dest: config['dest'], variables: config
  Log.info 'build ok'
end

if params.key?(:serve)
  out = config['dest'].tr('./', '')
  exec "ruby -run -e httpd -- #{out} -p #{params[:serve] ||= '0'}"
  end
