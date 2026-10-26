# frozen_string_literal: true

require "rails/railtie"

module AuditLogger
  class Railtie < Rails::Railtie
    initializer "audit_logger.active_record" do
      ActiveSupport.on_load(:active_record) do
        include AuditLogger::Auditable
      end
    end

    generators do
      require_relative "../generators/audit_logger/install_generator"
      require_relative "../generators/audit_logger/upgrade_generator"
    end
  end
end
