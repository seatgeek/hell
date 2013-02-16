# encoding: utf-8

require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'
require 'jeweler'

Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "hell"
  gem.homepage = "http://github.com/seatgeek/hell"
  gem.license = "MIT"
  gem.summary = %Q{A web interface and api wrapper around Capistrano}
  gem.description = %Q{Hell is an open source web interface that exposes a set of capistrano recipes as a json api, for usage within large teams}
  gem.email = "jose@seatgeek.com"
  gem.authors = ["Jose Diaz-Gonzalez"]
  gem.executables = ["hell", "hell-pusher"]
end
Jeweler::RubygemsDotOrgTasks.new

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "hell #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
