module RailsDbBrowser
  class DbBrowser < Sinatra::Base
    enable :session
    set :views, File.join(File.dirname(__FILE__), '../../views')
    
    class FakeModel < ActiveRecord::Base
      @abstract_class = true
      CONNECTS = {}
      def self.get_connection(name)
        CONNECTS[name] ||= begin
          establish_connection(name)
          connection
        end
      end
    end
    
    helpers do
      def connection
        if params[:connection].present?
          FakeModel.get_connection(params[:connection].to_s)
        else
          ActiveRecord::Base.connection
        end
      end
      
      def configurations
        ActiveRecord::Base.configurations
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
      
      def fields_to_head
        %w{id name login value}
      end
      
      def fields_to_tail
        %w{created_at created_on updated_at updated_on}
      end
      
      def columns(table)
        connection.columns(table)
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
    
    def select_all(sql)
      set_default_perpage
      case sql
      when /\s*select/i , /\s*(update|insert|delete).+returning/im
        if sql =~ /\s*select/i && per_page = params[:perpage].presence.try(:to_i)
          @count = connection.select_value("select count(*) from (#{sql}) as t")
          @pages = (@count.to_f / per_page.to_i).ceil
          params[:page] ||= '1'
          @page = params[:page].to_i
          sql = "select * from (#{sql}) as t"
          connection.add_limit_offset!( sql, :limit => per_page, :offset => per_page * (@page - 1))
        end
        @rezult = connection.select_all( sql )
      when /\s*update/i
        @rezult = connection.update( sql )
      when /\s*insert/i
        @rezult = connection.insert( sql )
      when /\s*delete/i
        @rezult = connection.delete( sql )
      end
    end
    
    get '/t/:table/s' do
      @columns = columns(params[:table])
      haml :table_structure
    end
    
    get '/t/:table' do
      @keys = columns(params[:table]).map{|c| c.name}
      quoted_name = connection.quote_table_name(params[:table])
      sql = "select * from #{quoted_name}"
      sql << "where #{params[:where]}" if params[:where].try(:strip).present?
      select_all( sql )
      haml :table_content
    end
    
    DEFAULT_QUERY = 'select * from'
    get '/' do
      if params[:query] && params[:query] != DEFAULT_QUERY
        select_all(params[:query])
      else
        set_default_perpage
      end
      @query = params[:query] || DEFAULT_QUERY
      haml :index
    end
  end
end
