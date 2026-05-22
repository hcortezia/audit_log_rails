# frozen_string_literal: true

module AuditLogger
  class ModelConfig
    # Guarda apenas a configuracao local da model, sem misturar com a global.
    attr_reader :humanize, :i18n_scopes, :humanizer, :ignored_attributes

    def initialize(humanize: nil, i18n_scopes: nil, humanizer: nil, ignored_attributes: [])
      @humanize = humanize
      @i18n_scopes = i18n_scopes
      @humanizer = humanizer
      @ignored_attributes = Array(ignored_attributes)

      validate!
    end

    # Resolve se a humanizacao ficara ativa considerando override local.
    def humanize_enabled?(global_configuration)
      return global_configuration.humanize_by_default if humanize.nil?

      humanize
    end

    # Retorna os escopos efetivos usados para traducao desta model.
    def effective_i18n_scopes(global_configuration)
      return global_configuration.i18n_scopes if i18n_scopes.nil? || i18n_scopes.empty?

      i18n_scopes
    end

    # Prioriza o humanizer da model e cai no global quando necessario.
    def effective_humanizer(global_configuration)
      humanizer || global_configuration.humanizer
    end

    # Combina ignored attributes globais e locais em uma lista unica.
    def effective_ignored_attributes(global_configuration)
      (global_configuration.ignored_attributes + ignored_attributes).map(&:to_s).uniq
    end

    private

    # Concentra as validacoes do contrato aceito pela DSL `auditable`.
    def validate!
      validate_humanize!
      validate_i18n_scopes!
      validate_humanizer!
      validate_ignored_attributes!
    end

    # Limita o override de humanizacao a valores simples e previsiveis.
    def validate_humanize!
      return if humanize.nil? || [true, false].include?(humanize)

      raise ConfigurationError, "humanize da model deve ser true, false ou nil"
    end

    # Garante que o fallback de I18n nao receba dados inconsistentes.
    def validate_i18n_scopes!
      return if i18n_scopes.nil?
      return if i18n_scopes.is_a?(Array) && i18n_scopes.all? { |item| item.is_a?(String) && !item.empty? }

      raise ConfigurationError, "i18n_scopes da model deve ser um Array de strings nao vazias"
    end

    # Mantem o ponto de extensao da model com a mesma regra do config global.
    def validate_humanizer!
      return if humanizer.nil? || humanizer.is_a?(Proc)

      raise ConfigurationError, "humanizer da model deve ser um Proc/Lambda ou nil"
    end

    # Normaliza a entrada para facilitar o filtro de atributos depois.
    def validate_ignored_attributes!
      return if ignored_attributes.all? { |item| item.is_a?(String) || item.is_a?(Symbol) }

      raise ConfigurationError, "ignored_attributes da model deve ser um Array de strings ou symbols"
    end
  end
end
