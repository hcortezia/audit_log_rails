# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module AuditLogger
  module Generators
    # Para quem instalou a 0.1.x: cria a migration das colunas owner_type/owner_id.
    class UpgradeGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Cria a migration que acrescenta owner_type/owner_id em audit_logs (upgrade da 0.1.x)."

      def copy_migration
        migration_template "add_owner_to_audit_logs.rb.tt", "db/migrate/add_owner_to_audit_logs.rb"
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::STRING.to_f}]"
      end

      def self.next_migration_number(path)
        ActiveRecord::Generators::Base.next_migration_number(path)
      end
    end
  end
end
