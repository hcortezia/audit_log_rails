# frozen_string_literal: true

module AuditLogger
  class ConfigValidator
    # Campos que aceitam estrategia configuravel via Proc/Lambda.
    CALLABLE_FIELDS = %i[
      changed_by_id_resolver
      changed_by_type_resolver
      changed_by_other_resolver
      uuid_resolver
      ip_resolver
      humanizer
      error_handler
    ].freeze

    def self.validate!(configuration)
      new(configuration).validate!
    end

    def initialize(configuration)
      @configuration = configuration
    end

    # Centraliza a validacao para falhar cedo no boot da aplicacao.
    def validate!
      validate_callable_fields!
      validate_humanize_by_default!
      validate_i18n_scopes!
      validate_ignored_attributes!
      validate_masked_attributes!
      validate_booleans!

      configuration
    end

    private

    attr_reader :configuration

    # Garante que os pontos extensivos da gem sejam sempre chamaveis.
    def validate_callable_fields!
      CALLABLE_FIELDS.each do |field_name|
        value = configuration.public_send(field_name)
        next if value.nil? || value.is_a?(Proc)

        raise ConfigurationError,
              "#{field_name} deve ser um Proc/Lambda ou nil"
      end
    end

    # Evita estados ambiguos de configuracao para humanizacao.
    def validate_humanize_by_default!
      return if [true, false].include?(configuration.humanize_by_default)

      raise ConfigurationError,
            "humanize_by_default deve ser true ou false"
    end

    # Obriga escopos consistentes para o fallback de traducao.
    def validate_i18n_scopes!
      value = configuration.i18n_scopes

      unless value.is_a?(Array) && value.all? { |item| item.is_a?(String) && !item.empty? }
        raise ConfigurationError,
              "i18n_scopes deve ser um Array de strings nao vazias"
      end
    end

    # Mesma regra dos ignorados: nomes de atributo como string ou symbol.
    def validate_masked_attributes!
      value = configuration.masked_attributes

      unless value.is_a?(Array) && value.all? { |item| item.is_a?(String) || item.is_a?(Symbol) }
        raise ConfigurationError,
              "masked_attributes deve ser um Array de strings ou symbols"
      end
    end

    # Flags simples nao aceitam valores "truthy" ambiguos.
    def validate_booleans!
      %i[resolve_associations raise_errors].each do |field_name|
        next if [true, false].include?(configuration.public_send(field_name))

        raise ConfigurationError, "#{field_name} deve ser true ou false"
      end
    end

    # Mantem a comparacao de atributos ignorados previsivel.
    def validate_ignored_attributes!
      value = configuration.ignored_attributes

      unless value.is_a?(Array) && value.all? { |item| item.is_a?(String) || item.is_a?(Symbol) }
        raise ConfigurationError,
              "ignored_attributes deve ser um Array de strings ou symbols"
      end
    end
  end
end
