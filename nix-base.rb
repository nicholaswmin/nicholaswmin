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
