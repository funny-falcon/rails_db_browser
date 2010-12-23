# RailsDbBrowser
require 'sinatra/base'
require 'rails_db_browser/url_truncate'
require 'rails_db_browser/connection_keeper'
require 'rails_db_browser/db_browser'

module RailsDbBrowser
  class Runner
    def initialize(path)
      @url_truncate = URLTruncate.new(DbBrowser, path)
    end
    
    def call(env)
      @url_truncate.call(env)
    end
  end
end
