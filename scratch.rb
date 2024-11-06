# frozen_string_literal: true

# # frozen_string_literal: true
#
# require 'bundler/inline'
# gemfile do
#   gem 'open-uri', '~> 0.4.1', require: true
#   gem 'kramdown', '~> 2.4.0', require: true
# end
#
# class Person
#   attr_reader :path, :data
#
#   def initialize(path, data)
#     @path = path
#     @data = data
#   end
#
#   def self.from(obj) = ->(path) { new(path, obj[path]) }
# end
#
# def read(...) = Pathname.glob(...)
#
# def write(dest, force: false)
#   lambda do |document|
#     path = Pathname.new(dest).join(document.path)
#     FileUtils.mkdir_p path.dirname
#     done = File.exist?(path) && !force ? false : File.write(path, document.data)
#     done ? pp("wrote #{path}") : pp("skipped #{path}. already-exists")
#   end
# end
#
# def create_files(url)
#   path = File.exist?(File.basename(url)) ? File.basename(url) : URI(url)
#   hash = YAML.load(path.is_a?(URI) ? path.read : File.read(path)).inject(:merge)
#   hash.keys.map(&Person.from(hash)).each(&write('./build', dest: true))
# end
#
# create_files('https://raw.githubusercontent.com/nicholaswmin/nix/main/init.yml')
# pp Pathname.glob('*.yml').map.first
# exit
