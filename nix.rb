#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'optparse', '~> 0.4.0', require: true
  gem 'kramdown', '~> 2.4.0', require: true
  gem 'kramdown-parser-gfm', '~> 1.1.0', require: true
  gem 'open-uri', '~> 0.4.1', require: true
  gem 'json', '~> 2.7.1', require: true
  gem 'logger', '~> 1.6.0', require: true
end

$PROGRAM_NAME = 'nix'
DOCS_URL = 'https://github.com/nicholaswmin/nix'
NO_COLORS = ENV['NO_COLORS'] || !$stdout.tty?

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
      .map(&:to_entry)
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
end

class Document
  attr_reader :path, :data

  def initialize(path, data = nil)
    @path = Pathname.new path.to_s
    @name = @path.parent.basename.to_s
    @data = data
  end

  def to_entry = [@path, @data]
end

class HTMLPage < Document
  def initialize(path:, title:)
    super(path)
    @title = title || @path.basename.to_s
  end

  def compile(layouts:, ctx:)
    type  = self.class.to_s.downcase
    name  = @path.basename(@path.extname).to_s

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

# --- Userland ---

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
    @date = begin
      Date.parse(markdown.lines[2]&.strip || '')
    rescue StandardError
      Date.today
    end
    super("/posts/#{path.basename(path.extname)}/index.html", markdown)
  end

  def render(ctx)
    "#{super}<link rel=\"stylesheet\" href=\"/public/highlight.css\"><link>"
  end
end

class Index < MarkdownPage
  def initialize(path, markdown)
    super("#{path}/index.html", markdown, 'Home')
  end

  def render(ctx)
    ispost = lambda do |item|
      item.instance_of?(::Post)
    end
    list_items = ctx[:pages].filter(&ispost).reduce(+'') do |list, post|
      list << <<~BODY
        <li>
          <a href="/posts/#{path.basename(path.extname)}">
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

# -- Initialisation --

class NoConfigError < StandardError
  attr_reader :detail

  def initialize
    super

    @detail = <<~BODY
      #{color('ERROR')}
      Cannot find _config.yml in current directory
      #{color('RESET')}#{color('WARN')}
      If you didnt create a site yet, run:\n
      $ nix --init#{' '}
      #{color('RESET')}
    BODY
  end
end

def color(level = 'reset')
  if NO_COLORS
    return ''
  end

  color = { 'WARN' => 33, 'INFO' => 32, 'ERROR' => 31, 'FATAL' => 31 }[level]
  color ? "\e[0;#{color}m" : "\033[m"
end

Log = Logger.new $stdout
Log.formatter = proc do |lvl, _datetime, _progname, msg|
  if lvl == 'FATAL'
    puts msg&.detail ||= ''
    raise msg
  end
  puts "#{color(lvl)}#{lvl} #{msg}#{color(lvl) ? color('reset') : ''}"
end

module FS
  def self.create(type) = lambda do |path|
    type.new(path, File.read(path))
  end

  def self.write(dest:, force: false)
    lambda do |(path, data)|
      pathname = Pathname.new File.join(dest, path)

      FileUtils.mkdir_p pathname.dirname

      if File.exist?(pathname) && !force
        return Log.warn("write #{pathname} skipped. exists")
      end

      File.write(pathname, data)
      Log.debug "write #{pathname} ok"
    end
  end
end

def init(url)
  Log.info "fetching files from: #{url} ..."
  JSON.parse(URI.parse(url).open.read)['files'].each(&FS.write(dest: './'))
end

def build(base:, dest:, variables:)
  Site
    .new(Pathname.glob('_layouts/*.html', base:).map(&FS.create(Layout)))
    .add(Pathname.glob('posts/*[^index]*.md', base:).map(&FS.create(Post)))
    .add(Pathname.glob('pages/*[^index].md', base:).map(&FS.create(Page)))
    .add(Pathname.glob('pages/index.md', base:).map(&FS.create(Index)))
    .compile(variables:)
    .map(&FS.write(dest:, force: true))

  FileUtils.cp_r(File.join(base, 'public/'), File.join(dest, 'public'))
end

params = {}
opts = OptionParser.new do |o|
  o.on('-i', '--init',  'create new sample site')
  o.on('-b', '--build', 'build HTML to output')
  o.on('-s', '--serve [PORT]', 'serve site at port', Integer)
  o.on('-h', '--help', 'print this help')
end
opts.parse!(into: params)

if params.key?(:help) || params.empty?
  puts "\n", $PROGRAM_NAME, "docs: #{DOCS_URL}\n\n", opts.help, "\n"
  exit
end

if params.key?(:init)
  init 'https://raw.githubusercontent.com/nicholaswmin/nix/main/init.json'
  Log.info 'init ok, you should commit files'
end

config = YAML.load_file '_config.yml'

if params.key?(:build)
  build base: config['base'], dest: config['dest'], variables: config
  Log.info 'build ok'
end

if params.key?(:serve)
  spawn "ruby -run -e httpd -- #{config['dest']} . -p #{params[:serve] ||= '0'}"
end
