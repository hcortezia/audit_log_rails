# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module AuditLogger
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Cria a migration inicial e o initializer base do AuditLogger."

      def copy_migration
        migration_template "create_audit_logs.rb.tt", "db/migrate/create_audit_logs.rb"
      end

      def copy_initializer
        template "audit_logger_initializer.rb.tt", "config/initializers/audit_logger.rb"
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
