module RailsDbBrowser
  # Abstract class holding connection staff
  class ConnectionKeeper
    # get connection names
    def connection_names
      ActiveRecord::Base.configurations.keys
    end

    def connection(name=nil)
      underlying = unless name.present?
        ActiveRecord::Base.connection
      else
        FakeModel.get_connection(name)
      end
      Connection.new(underlying)
    end

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

    # performs common operations on connection
    class Connection
      attr_accessor :connection
      delegate :quote_table_name, :quote_column_name, :select_value, 
               :select_all, :update, :insert, :delete,
               :add_limit_offset!,
               :to => :connection

      def initialize(connection)
        @connection = connection
      end

      # getting list of column definitions 
      # and order them to be more human readable
      def columns(table)
        columns = get_column_definitions(table)
        columns.sort_by{|c| 
          [
            fields_to_head.index(c.name) || 1e6,
            -(fields_to_tail.index(c.name) || 1e6),
            c.name
          ]
        }
      end

      def column_names(table)
        columns(table).map{|c| c.name}
      end

      def table_names
        @connection.tables.sort
      end

      # fields to see first
      def fields_to_head
        @fields_to_head ||= %w{id name login value}
      end

      # fields to see last
      def fields_to_tail
        @fields_to_tail ||= %w{created_at created_on updated_at updated_on}
      end

      attr_writer :fields_to_head, :fields_to_tail

      # sort field names in a rezult
      def sort_fields(fields)
        fields = (fields_to_head & fields) | (fields - fields_to_head)
        fields = (fields - fields_to_tail) | (fields_to_tail & fields)
        fields
      end

      # performs query with appropriate method
      def query(sql, opts={})
        per_page = (opts[:perpage] || nil).to_i
        page     = (opts[:page]    || 1  ).try(:to_i)
        fields   = opts[:fields]   || nil
        case sql
        when /\s*select/i , /\s*(update|insert|delete).+returning/im
          rez = {:fields => fields}
          if sql =~ /\s*select/i && per_page > 0
            rez[:count] = select_value("select count(*) from (#{sql}) as t").to_i
            rez[:pages] = (rez[:count].to_f / per_page).ceil
            sql = "select * from (#{sql}) as t"
            add_limit_offset!( sql, 
                              :limit => per_page,
                              :offset => per_page * (page - 1))
          end

          rez[:rows] = select_all( sql )

          unless rez[:fields].present? && rez[:rows].blank?
            rez[:fields] = self.sort_fields(rez[:rows].first.keys)
          end

          Result.new(rez)
        when /\s*update/i
          Result.new :value => update( sql )
        when /\s*insert/i
          Result.new :value => insert( sql )
        when /\s*delete/i
          Result.new :value => delete( sql )
        end
      rescue StandardError => e
        Result.new :error => e
      end

      private
      def get_column_definitions(table)
        @connection.columns(table).map{|c|
          Column.new(c.name, c.sql_type, c.default, c.null)
        }
      end

    end

    class Column
      attr_accessor :name, :type, :default, :null
      def initialize(name, type, default, null)
        @name = name
        @type = type
        @default = default
        @null = null
      end
    end

    class Result
      attr_accessor :rows, :count, :pages, :fields, :error
      def initialize(opts={})
        if opts[:value]
          @value = [opts[:value]]
        elsif opts[:rows]
          @rows = opts[:rows]
          @count = opts[:count] || @rows.size
          @pages = opts[:pages] || 1
          @fields = opts[:fields]
        elsif opts[:error]
          @error = opts[:error]
        end
      end

      def value
        @value && @value[0]
      end

      def value?
        @value.present?
      end

      def error?
        @error.present?
      end

      def rows?
        @rows != nil
      end
    end
  end
end
