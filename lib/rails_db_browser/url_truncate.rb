module RailsDbBrowser
  # do mostly same thing as Rack::URLMap
  # but UrlMapper could not work under Rails
  # usage:
  #    mounted_app = RailsDbBrowser::URLTruncate.new( RackApplication, '/path')
  #    mounted_app = RailsDbBrowser::URLTruncate.new( '/path') do |env| [200, {'Content-type': 'text/plain'}, [env.inspect]] end
  #    app = Rack::Builder.app do
  #      use RailsDbBrowser::URLTruncate, '/path'
  #      run RackApplication
  #    end
  class URLTruncate
    def initialize(app_or_path, path = nil, &block)
      @path = path || app_or_path 
      @app = block || app_or_path
    end
    
    def call(env)
      path, script_name = env.values_at("PATH_INFO", "SCRIPT_NAME")
      if path.start_with?(@path)
        env.merge!('SCRIPT_NAME' => (script_name + @path), 'PATH_INFO' => path[@path.size .. -1] )
        @app.call(env)
      else
        [404, {"Content-Type" => "text/plain", "X-Cascade" => "pass"}, ["Not Found: #{path}"]]
      end
    ensure
      env.merge!  'PATH_INFO' => path, 'SCRIPT_NAME' => script_name
    end
  end
end
