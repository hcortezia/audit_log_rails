# frozen_string_literal: true

module AuditLogger
  class ActorContextResolver
    def self.call(configuration)
      new(configuration).call
    end

    def initialize(configuration)
      @configuration = configuration
    end

    # Resolve todos os campos de contexto do ator em um unico ponto.
    def call
      {
        changed_by_id: call_resolver(:changed_by_id, configuration.changed_by_id_resolver),
        changed_by_type: call_resolver(:changed_by_type, configuration.changed_by_type_resolver),
        changed_by_other: normalize_json_object(call_resolver(:changed_by_other, configuration.changed_by_other_resolver)),
        uuid: resolve_uuid,
        ip_remote: call_resolver(:ip_remote, configuration.ip_resolver)
      }
    end

    private

    attr_reader :configuration

    # Executa o resolver apenas quando ele foi configurado e isola falhas.
    def call_resolver(label, resolver)
      return nil if resolver.nil?

      resolver.call
    rescue StandardError => e
      log_warning(label, e)
      nil
    end

    # Garante que o metadado adicional sempre seja persistido como objeto JSON.
    def normalize_json_object(value)
      return {} if value.nil?
      return value if value.is_a?(Hash)

      { value: value }
    end

    # Mantem um fallback seguro para correlacao quando o app nao informar uuid.
    def resolve_uuid
      value = call_resolver(:uuid, configuration.uuid_resolver)
      return value if value && !value.to_s.empty?

      SecureRandom.uuid
    end

    # Evita que falhas de contexto derrubem a auditoria inteira da requisicao.
    def log_warning(label, error)
      message = "[AuditLogger] Falha ao resolver #{label}: #{error.class} - #{error.message}"

      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn(message)
      else
        warn(message)
      end
    end
  end
end
