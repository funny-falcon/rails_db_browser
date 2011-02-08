module RailsDbBrowser
  class TableColumns < Struct.new(:table, :columns)
  end

  class DbBrowser < Sinatra::Base
    enable :session
    set :views, File.join(File.dirname(__FILE__), '../../views')
    set :public, File.join(File.dirname(__FILE__), '../../public')
    set :connect_keeper, ConnectionKeeper.new
    enable :show_exceptions

    helpers do
      def logger
        ActiveRecord::Base.logger
      end

      def keeper
        settings.connect_keeper
      end
      
      def connection
        keeper.connection(params[:connection])
      end
      
      def connection_names
        keeper.connection_names
      end
      
      def url(path, add_params={})
        path = path.sub(%r{/+$},'')
        query = add_params.to_query
        relative = query.present? ? "#{path}?#{query}" : path
        "#{request.script_name}#{relative}"
      end

      def keep_params(path, add_params={})
        url path, params.slice("connection", "perpage").merge(add_params)
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

      def extract_tables(fields)
        tables = []
        for field in fields
          if field =~ /(?:([\w\.]+)\.)?(\w+)/
            table, column = $1, $2
          else
            table, column = nil, field
          end
          if !tables.last || tables.last.table != table
            tables << TableColumns.new(table, [column])
          else
            tables.last.columns << column
          end
        end
        tables
      end
      
      def inspect_env
        haml <<'HAML', :layout => false
%pre
  \ 
  - env.sort.each do |k, v|
    & #{k} = #{v.inspect}
HAML
      end

      def table_content_url(table)
        keep_params("/t/#{table}")
      end

      def table_scheme_url(table)
        keep_params("/s/#{table}")
      end
    end

    def quote_table_name(t)
      connection.quote_table_name(t)
    end

    def quote_column_name(c)
      connection.quote_column_name(c)
    end
    
    def set_default_perpage
      params['perpage'] = '25' unless params.has_key?('perpage')
    end

    def extract_fields_from_special(sql)
      fields = []
      sql = sql.gsub(/\[\[([\w.]+)\.\*(?:\s*-\s*((?:\w+[,\s]+)*(?:\w+))\s*)?\]\]/) do 
        table, without = $1, ($2 || '').scan(/\w+/)
        table_fields = column_names(table) - without

        table_fields.map{|fld|
          as = "#{table}.#{fld}"
          fields << as
          "#{quote_table_name(table)}.#{quote_column_name(fld)} as #{quote_column_name(as)}"
        }.join(',')
      end
      [ sql, fields ]
    end
    
    def select_all(sql, fields=nil)
      set_default_perpage
      unless fields.present?
        sql, fields = extract_fields_from_special(sql)
      end
      connection.query(sql,
                       :perpage => params[:perpage],
                       :page    => params[:page],
                       :fields  => fields
                      )
    end
   
    get '/d' do
      File.mtime(__FILE__).to_s+"<br/>\n"+
        env.map{|k,v| "#{k.inspect} => #{v.inspect} <br/>\n" }.join
    end
    get '/s/:table' do
      @columns = columns(params[:table])
      haml :table_structure
    end
    
    get '/t/:table' do
      quoted_name = connection.quote_table_name(params[:table])
      sql = "select * from #{quoted_name} "
      unless params[:where].try(:strip).present?
        params[:where] = "WHERE 1=1"
        if column_names(params[:table]).include?("id")
          params[:where] += "\nORDER BY id"
        end
      end
      sql << params[:where]
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
