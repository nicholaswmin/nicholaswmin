#!/usr/bin/env ruby

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
      .map(&:to_entry)
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
  attr_reader :path, :data

  def initialize path, data = nil
    @path = Pathname.new path.to_s
    @name = @path.parent.basename.to_s
    @data = data
  end
  
  def to_entry() [@path, @data] end
end

class HTMLPage < Document
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

# --- Userland ---

class MarkdownPage < HTMLPage
  attr_reader :title

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
      markdown.lines.first[2..-1].strip : 'Untitled'
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
    list_items = ctx[:pages].filter(&ispost).reduce('') do |list,post| 
      list << post = <<~BODY
      <li>
        <a href="#{post.link}">
          <h3>#{post.title}</h3> 
          <small>#{post.date.strftime('%b, %Y')}</small> 
        </a>
      </li>
      BODY
    end

    super(ctx) + <<~BODY.squeeze("\n")
      <ul class="list">
        #{list_items}
      </ul>
    BODY
  end
end

# -- Initialisation --

$0 = "nix"
NO_COLORS = ENV['NO_COLORS'] || !$stdout.tty?

class NoConfigError < StandardError
  attr_reader :detail

  def initialize
    @detail = <<~BODY      
      #{color('ERROR')}
      Cannot find _config.yml in current directory
      #{color('RESET')}#{color('WARN')}
      If you didnt create a site yet, run:\n
      $ nix --init 
      #{color('RESET')}
     BODY
  end
end

def color level
  color = { 'WARN' => 33, 'INFO' => 32, 'ERROR' => 31, 'FATAL' => 31 }[level]
  NO_COLORS ? '' : "\e[0;#{color}m"
end

Log = Logger.new $stdout
Log.formatter = proc do |level, datetime, progname, msg|  
  if level == 'FATAL' 
    puts msg&.detail ||= ''
    raise msg
  else
    puts "#{color(level)}#{level} #{msg}#{color(level) ? color('reset') : '' }"
  end
end

module FS
  def self.create(type) -> path do type.new(path, File.read(path)) end end

  def self.write(dest:, force: false) 
    -> ((path, data)) do 
      pathname = Pathname.new File.join(dest, path)
      
      FileUtils.mkdir_p pathname.dirname
      
      if File.exist?(pathname) && !force
        return Log.warn("| write |#{pathname} | skipped, exists") 
      end
  
      File.write(pathname, data); 
      Log.debug "| write | #{pathname}"
    end
  end
end

def init url 
  Log.info "| fetching | samples from: #{url} ..."
  JSON.load(URI.open(url)).each(&FS::write(dest: './')) 
end 

def build config 
  base = config['base']
  dest = config['dest']   

Site
  .new(Pathname.glob('_layouts/*.html', base:).map(&FS::create(Layout)))
  .add(Pathname.glob('posts/*[^index]*.md', base:).map(&FS::create(Post)))
  .add(Pathname.glob('pages/*[^index].md', base:).map(&FS::create(Page)))
  .add(Pathname.glob('pages/index.md', base:).map(&FS::create(Index)))
  .compile(variables: config) 
  .map(&FS::write(dest:, force: true))

  FileUtils.cp_r(File.join(base, 'public/'), File.join(dest, 'public'))  
end

params = {}
opts = OptionParser.new("\ndocs: https://github.com/nicholaswmin/nix \n") do |o|
  o.on('-i', '--init',  "create new sample site")
  o.on('-b', '--build', "build site to output")
  o.on('-s PORT', '--serve PORT', "start dev. server at PORT", Integer)
  o.on('-h', '--help',  "print this help")
end; opts.parse!(into: params)

if params[:help] || params.empty?
  puts $0, color('INFO'), opts.help, color('reset')
end

if params[:build]
  build YAML.load_file '_config.yml' rescue
    Log.fatal NoConfigError.new

  Log.info '| build | ok'
end

if (params[:init])
  init 'https://raw.githubusercontent.com/nicholaswmin/nix/main/init.json'
  Log.info '| init | ok | you should commit & push these files!'
end

if params[:serve]
  spawn "ruby -run -e httpd . -p #{params[:serve] ||= 0}"
end

puts "\n"
