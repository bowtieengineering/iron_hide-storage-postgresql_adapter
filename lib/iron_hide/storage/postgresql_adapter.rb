require 'multi_json'
require 'iron_hide'
require "iron_hide/storage"
require 'pg'
# require 'active_record'

module IronHide
  class Storage
    class PostgresqlAdapter
      # @option opts [String] :resource *required*
      # @option opts [String] :action *required*
      # @return [Array<Hash>] array of canonical JSON representation of rules
      def where(opts = {})
        # ::Rule.where("rules->>'resource' = :resource", resource: opts.fetch(:resource)).where("rules->'action' ?| array[:action]", action: opts.fetch(:action))
        storage_find(opts.fetch(:resource),opts.fetch(:action))
      end

      # no longer the case
      # Implements an interface that makes selecting rules look like a Hash:
      # @example
      #   {
      #     'com::test::TestResource::read' => {
      #       ...
      #     }
      #   }
      #  adapter['com::test::TestResource::read']
      #  #=> [Array<Hash>]
      #
      # @param [String] resource
      # @param [String] action
      # @return [Array<Hash>] array of canonical JSON representation of rules
      def storage_find(resource, action)
        # resource_where = dash_double_arrow(table[:rules],Arel::Nodes.build_quoted('resource')).eq(Arel::Nodes.build_quoted(resource))
        # action_where = question_or(dash_double_arrow(table[:rules],Arel::Nodes.build_quoted('action')),cast_as_array(Arel::Nodes.build_quoted(action)))
        # request = table.project(table[:rules]).where(resource_where.and(action_where))
        # binding.pry
        # response = execute request.to_sql
        begin
          database_connect
          @db.prepare("get_rules_by_resource_and_action", "Select rules.rules from rules where (rules->>'resource' = $1) AND (rules->'action' ?| array[$2])")
          response = @db.exec_prepared("get_rules_by_resource_and_action", [resource, action])
        ensure
          @db.close
        end
        if response.cmd_tuples > 0
          response.field_values("rules").reduce([]) do |rval,row|
            rval << MultiJson.load(row)
          end
        else
          []
          # Do Something
        end
      end

    private
      def dash_double_arrow(left,right)
        Arel::Nodes::InfixOperation.new('->>',left, right)
      end

      def question(left,right)
        Arel::Nodes::InfixOperation.new('?',left, right)
      end

      def question_and(left,right)
        Arel::Nodes::InfixOperation.new('?&',left, right)
      end

      def question_or(left,right)
        Arel::Nodes::InfixOperation.new('?|',left, right)
      end

      def cast_as_text(string)
        Arel::Nodes::NamedFunction.new "TEXT", [string]
      end

      def cast_as_array(ary,delimiter=",")
        Arel::Nodes::NamedFunction.new "string_to_array", [ary,Arel::Nodes.build_quoted(delimiter)]
      end

      def table
        Arel::Table.new(IronHide.configuration.postgresql_table, database)
      end

      def database_connect
        # if defined? ActiveRecord::Base
          # ActiveRecord::Base
        # else
        @db = PG.connect(host: IronHide.configuration.postgresql_host, port: IronHide.configuration.postgresql_port, user: IronHide.configuration.postgresql_user, password: IronHide.configuration.postgresql_password, dbname: IronHide.configuration.postgresql_dbname)
        # end
      end

      def execute(sql)
        ActiveRecord::Base.connection.execute sql
      end
    end
  end
end

IronHide::Storage::ADAPTERS.merge!(postgresql: :PostgresqlAdapter)

IronHide.configuration.add_configuration(postgresql_host: '127.0.0.1',
                                         postgresql_port: 5432,
                                         postgresql_user: 'postgres',
                                         postgresql_password: '',
                                         postgresql_dbname: 'postgres',
                                         postgresql_table: 'rules')
