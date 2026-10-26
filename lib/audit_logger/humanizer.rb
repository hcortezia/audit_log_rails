# frozen_string_literal: true

module AuditLogger
  class Humanizer
    def initialize(record:, payload:, model_config:, configuration:)
      @record = record
      @payload = payload
      @model_config = model_config
      @configuration = configuration
    end

    # Gera o payload humanizado mantendo a mesma estrutura do payload bruto.
    def call
      return empty_payload unless model_config.humanize_enabled?(configuration)

      {
        "type" => payload["type"],
        "fields" => humanized_fields
      }
    end

    private

    attr_reader :record, :payload, :model_config, :configuration

    # Quando a humanizacao estiver desabilitada, preserva apenas o tipo da acao.
    def empty_payload
      {
        "type" => payload["type"],
        "fields" => {}
      }
    end

    # Humaniza campo por campo para permitir fallback individual.
    def humanized_fields
      payload.fetch("fields", {}).each_with_object({}) do |(attribute, values), result|
        result[attribute] = build_field_payload(attribute, values)
      end
    end

    # Tenta humanizer customizado primeiro e cai no comportamento padrao.
    def build_field_payload(attribute, values)
      custom_result = call_custom_humanizer(attribute, values)
      return normalize_custom_result(attribute, values, custom_result) unless custom_result.nil?

      default_field_payload(attribute, values)
    end

    # O humanizer recebe model, atributo e valores bruto para maximo contexto.
    def call_custom_humanizer(attribute, values)
      humanizer = model_config.effective_humanizer(configuration)
      return nil if humanizer.nil?

      humanizer.call(record.class, attribute, values["old_value"], values["new_value"] || values["value"])
    rescue StandardError => e
      log_warning(attribute, e)
      nil
    end

    # Aceita retorno em Hash para sobrescrita rica ou valor simples para casos basicos.
    def normalize_custom_result(attribute, values, custom_result)
      return default_field_payload(attribute, values).merge(stringify_keys(custom_result)) if custom_result.is_a?(Hash)

      default_field_payload(attribute, values).merge("value" => custom_result)
    end

    # Mantem o label traduzido e preserva os dados do payload bruto.
    # Em belongs_to, acrescenta o rotulo do registro associado: "r_cargo_id: 3 -> 7" vira
    # old_value_label "PROFESSOR" e new_value_label "ASSESSOR".
    def default_field_payload(attribute, values)
      result = { "label" => translate_attribute(attribute) }

      values.each do |key, value|
        result[key] = value
      end

      result.merge(association_labels(attribute, values))
    end

    VALUE_KEYS = %w[old_value new_value value].freeze

    def association_labels(attribute, values)
      return {} unless configuration.resolve_associations

      reflection = belongs_to_reflection(attribute)
      return {} unless reflection

      values.each_with_object({}) do |(key, value), labels|
        next unless VALUE_KEYS.include?(key) && !value.nil?

        label = association_label(reflection, value)
        labels["#{key}_label"] = label unless label.nil?
      end
    rescue StandardError => e
      log_warning(attribute, e)
      {}
    end

    def belongs_to_reflection(attribute)
      record.class.reflect_on_all_associations(:belongs_to).find do |reflection|
        !reflection.polymorphic? && reflection.foreign_key.to_s == attribute.to_s
      end
    end

    # Procura tambem registros excluidos (soft delete): o historico precisa do nome antigo.
    def association_label(reflection, id)
      klass = reflection.klass
      scope = klass.respond_to?(:with_deleted) ? klass.with_deleted : klass.unscoped
      associated = scope.find_by(reflection.association_primary_key => id)
      associated && display_label(associated)
    end

    LABEL_METHODS = %i[display_name descricao nome name title].freeze

    # Prefere um to_s definido na propria model; depois metodos comuns de rotulo.
    def display_label(associated)
      owner = associated.class.instance_method(:to_s).owner
      return associated.to_s if owner.is_a?(Class) && owner < ActiveRecord::Base

      method_name = LABEL_METHODS.find { |name| associated.respond_to?(name) }
      method_name && associated.public_send(method_name)&.to_s
    end

    # Faz o fallback de traducao por escopo ate encontrar um label valido.
    def translate_attribute(attribute)
      scopes = model_config.effective_i18n_scopes(configuration)
      model_key = record.class.model_name.i18n_key

      scopes.each do |scope|
        translation = I18n.t("#{scope}.#{model_key}.#{attribute}", default: nil)
        return translation if translation

        fallback = I18n.t("#{scope}.#{attribute}", default: nil)
        return fallback if fallback
      end

      attribute.to_s.humanize
    end

    # Normaliza chaves vindas do humanizer customizado para JSON consistente.
    def stringify_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        result[key.to_s] = value
      end
    end

    # Evita que falhas no humanizer customizado interrompam a gravacao da auditoria.
    def log_warning(attribute, error)
      message = "[AuditLogger] Falha ao humanizar #{record.class.name}##{attribute}: #{error.class} - #{error.message}"

      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn(message)
      else
        warn(message)
      end
    end
  end
end
