module RailsDbBrowser
  class DbBrowser < Sinatra::Base
    enable :session
    
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
        haml <<'HAML', :layout => false
%label(for="connection_name") Connection:
%select.connection_name(name="connection")
  %option(value="") Default
  - configurations.keys.each do |n|
    %option{:value=>n, :selected=>n == params[:connection]}= n
HAML
      end
      
      def per_page_field
        haml <<'HAML', :layout => false
%label(for="rezult_perpage") Per page:
%select.rezult_perpage(name="perpage")
  %option(value="") No Limits
  - %w{10 25 50 100 250 500 1000}.each do |n|
    %option{:value=>n, :selected=> n == params[:perpage]}= n
HAML
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
      if per_page = params[:perpage].presence.try(:to_i)
        @count = connection.select_value("select count(*) from (#{sql}) as t")
        @pages = (@count.to_f / per_page.to_i).ceil
        @page = (params[:page].presence || '1').to_i
        sql = "select * from (#{sql}) as t"
        connection.add_limit_offset!( sql, :limit => per_page, :offset => per_page * (@page - 1))
      end
      @rezult = connection.select_all( sql )
    end
    
    get '/t/:table/s' do
      @columns = columns(params[:table])
      haml <<'HAML'
%h1&= "Table #{params[:table]}"
%a{:href=>keep_params(env['SCRIPT_NAME'])} goto queries
%a{:href=>keep_params(env['SCRIPT_NAME']+"/t/#{params[:table]}")} goto table
%form(method="get")
  = connection_field
  %input{:type=>"hidden", :name=>"perpage", :value=>params[:perpage]}
  %input(type="submit")
%table.columns
  %thead
    %tr
      %th Name
      %th Type
      %th Default
      %th Not Null
  %tbody
    - @columns.each do |col|
      %tr
        %td= col.name
        %td= col.sql_type
        %td&= col.default.inspect
        %td= col.null
HAML
    end
    
    get '/t/:table' do
      @keys = columns(params[:table]).map{|c| c.name}
      quoted_name = connection.quote_table_name(params[:table])
      select_all( "select * from #{quoted_name}" )
      haml <<'HAML'
%h1&= "Table #{params[:table]}"
%a{:href=>keep_params(env['SCRIPT_NAME'])} goto queries
%a{:href=>keep_params(env['SCRIPT_NAME']+"/t/#{params[:table]}/s")} goto schema
%form(method="get")
  = connection_field
  = per_page_field
  %input(type="submit")
= haml :rezult, :layout => false
HAML
    end
    
    DEFAULT_QUERY = 'select * from'
    get '/' do
      if params[:query] && params[:query] != DEFAULT_QUERY
        select_all(params[:query])
      else
        set_default_perpage
      end
      @value = params[:query] || DEFAULT_QUERY
      haml <<'HAML'
%form(method="get")
  = connection_field
  = per_page_field
  %br
  %textarea(name="query" cols="60" rows=10)= @value
  %br
  %input(type="submit")
  = haml :rezult, :layout => false
HAML
    end
    
    template :rezult do <<'HAML'
.rezult
  - if @rezult
    - if @rezult.present? || @keys
      - keys = @keys || @rezult.first.keys.sort
      - keys = (fields_to_head & keys) | (keys - fields_to_head)
      - keys = (keys - fields_to_tail) | (fields_to_tail & keys)
      %strong= "Total: #{@count || @rezult.size}"
      - if @pages.presence.to_i > 1
        = haml :pages, :layout => false
      %table
        %thead
          %tr
            - keys.each do |key|
              %th&= key
        %tbody
          - @rezult.each do |row|
            %tr
              - keys.each do |key|
                - value = row[key]
                - if value.try(:strip).present?
                  %td&= value
                - else
                  %td.inspect&= value.inspect
      - if @pages.presence.to_i > 1
        = haml :pages, :layout => false
    - else
      Has no rezult
HAML
    end
    
    template :pages do <<'HAML'
.pages
  - 1.upto(@pages) do |i|
    - unless i == params[:page].to_i
      %a{:href=> merge_params("page" => i)}= i
    - else
      = i
HAML
    end
    
    template :layout do
      <<'HAML'
%html
  %style
    :sass
      $hover-background-color: #dfd
      table
        border-spacing: 0
        thead tr th
          border-bottom: 1px solid black
        td, th
          border-right: 1px solid black
          &:last-child
            border-right: 0 none
        td.inspect
          background-color: grey
        tbody tr:hover
          background-color: $hover-background-color
      .dbtables
        float: left
        width: 200px
        padding-right: 10px
        h4
          margin: 0.5em 0
          padding: 0
        .list
          height: 200px
          overflow: auto
          .dbtable
            a.q
              display: inline-block
              width: 155px
      .rezult
        clear: left
  %body
    = haml :dbtables, :layout => false
    %div.main= yield
    
HAML
    end
    
    template :dbtables do <<'HAML'
%div.dbtables
  %h4 Tables list:
  - url_pat = keep_params(env["SCRIPT_NAME"] + "/t/%t%")
  .list
    - connection.tables.sort.each do |tname|
      .dbtable
        %a.q{:href=>url_pat.sub("/%t%", "/#{tname}")}= tname
        %a.s{:href=>url_pat.sub("/%t%", "/#{tname}/s")} (s)
HAML
    end
  end
end
