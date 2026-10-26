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
require_relative "audit_logger/owner_resolver"
require_relative "audit_logger/persistence"
require_relative "audit_logger/record_audit_entry"
require_relative "audit_logger/record_event"
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

    # Registra um evento que nao passa pelos callbacks (reset de senha, login, update_all).
    # Ver AuditLogger::RecordEvent para as opcoes.
    def record_event(**options)
      RecordEvent.call(**options)
    end

    # A auditoria nunca derruba a operacao principal: registra o erro, chama o error_handler
    # e segue. Com raise_errors = true (util em teste) o erro sobe.
    def safely(record: nil, action: nil)
      yield
    rescue StandardError => e
      raise if configuration.raise_errors

      report_error(e, record, action)
      nil
    end

    private

    def report_error(error, record, action)
      alvo = record ? " de #{record.class.name}##{record.id}" : ""
      message = "[AuditLogger] Falha ao registrar #{action}#{alvo}: #{error.class} - #{error.message}"
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.error(message)
      else
        warn(message)
      end
      configuration.error_handler&.call(error, record, action)
    rescue StandardError
      nil
    end
  end
end

require_relative "audit_logger/railtie" if defined?(Rails::Railtie)
