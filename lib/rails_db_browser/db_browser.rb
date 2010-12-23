module RailsDbBrowser
  class DbBrowser < Sinatra::Base
    enable :session
    set :views, File.join(File.dirname(__FILE__), '../../views')
    set :connect_keeper, ConnectionKeeper.new
    enable :show_exceptions

    helpers do
      def keeper
        settings.connect_keeper
      end
      
      def connection
        keeper.connection(params[:connection])
      end
      
      def connection_names
        keeper.connection_names
      end
      
      def keep_params(url, add_params={})
        query = params.slice("connection", "perpage").merge(add_params).to_query
        query.present? ? "#{url}?#{query}" : url
      end
      
      def merge_params(add_params)
        query = params.merge(add_params).to_query
        query.present? ? "?#{query}" : ""
      end
      
      def connection_field
        haml :_connection_field, :layout => false
      end
      
      def per_page_field
        haml :_per_page_field, :layout => false
      end
       
      def columns(table)
        connection.columns(table)
      end

      def column_names(table)
        connection.column_names(table)
      end
      
      def inspect_env
        haml <<'HAML', :layout => false
%pre
  \ 
  - env.sort.each do |k, v|
    & #{k} = #{v.inspect}
HAML
      end
    end
    
    def set_default_perpage
      params['perpage'] = '25' unless params.has_key?('perpage')
    end
    
    def select_all(sql, fields=nil)
      set_default_perpage
      connection.query(sql,
                       :perpage => params[:perpage],
                       :page    => params[:page],
                       :field   => fields
                      )
    end
    
    get '/t/:table/s' do
      @columns = columns(params[:table])
      haml :table_structure
    end
    
    get '/t/:table' do
      quoted_name = connection.quote_table_name(params[:table])
      sql = "select * from #{quoted_name}"
      sql << "where #{params[:where]}" if params[:where].try(:strip).present?
      @result = select_all( sql, column_names(params[:table]) )
      haml :table_content
    end
    
    DEFAULT_QUERY = 'select * from'
    get '/' do
      if params[:query] && params[:query] != DEFAULT_QUERY
        @result = select_all(params[:query])
      else
        set_default_perpage
      end
      @query = params[:query] || DEFAULT_QUERY
      haml :index
    end

    get '/css.css' do
      sass :css
    end
  end
end
