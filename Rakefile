require 'rake'
require 'rake/rdoctask'

desc 'Generate documentation for the db_browser plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'DbBrowser'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "rails_db_browser"
    gemspec.summary = "Simple database browser for Rails application backed by ActiveRecord"
    gemspec.description = "Simple sinatra Rack application that allowes to run sql queries from a web page. Usable for administrative tasks."
    gemspec.email = "funny.falcon@gmail.com"
    gemspec.homepage = "http://github.com/funny-falcon/rails_db_browser"
    gemspec.authors = ["Sokolov Yura aka funny_falcon"]
    gemspec.add_dependency('rails')
    gemspec.add_dependency('activerecord')
    gemspec.add_dependency('sinatra')
    gemspec.add_dependency('haml')
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end