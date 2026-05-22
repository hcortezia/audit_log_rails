# frozen_string_literal: true

require_relative "audit_logger/version"
require "active_support"
require "active_support/concern"
require "active_record"
require "i18n"
require "json"
require "securerandom"
require_relative "audit_logger/configuration"
require_relative "audit_logger/config_validator"
require_relative "audit_logger/model_config"
require_relative "audit_logger/audit_log"
require_relative "audit_logger/actor_context_resolver"
require_relative "audit_logger/change_extractor"
require_relative "audit_logger/humanizer"
require_relative "audit_logger/record_audit_entry"
require_relative "audit_logger/auditable"

module AuditLogger
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    # Retorna a configuracao global da gem, instanciando-a sob demanda.
    def configuration
      @configuration ||= Configuration.new
    end

    # Permite configurar a gem via bloco e valida o resultado no final.
    def configure
      yield(configuration)
      ConfigValidator.validate!(configuration)
      configuration
    end

    # Facilita testes e reconfiguracao do estado global da gem.
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

require_relative "audit_logger/railtie" if defined?(Rails::Railtie)
