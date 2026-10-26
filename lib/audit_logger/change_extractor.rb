# frozen_string_literal: true

module AuditLogger
  class ChangeExtractor
    def initialize(record:, action:, model_config:, configuration:)
      @record = record
      @action = action.to_s
      @model_config = model_config
      @configuration = configuration
    end

    # Retorna o payload bruto no formato padronizado da gem.
    def call
      {
        "type" => action,
        "fields" => extract_fields
      }
    end

    private

    attr_reader :record, :action, :model_config, :configuration

    # Direciona a extracao conforme o tipo da acao auditada.
    def extract_fields
      case action
      when "create"
        snapshot_fields
      when "update"
        update_fields
      when "destroy"
        snapshot_fields
      else
        {}
      end
    end

    # Usa snapshot completo em create e destroy para preservar contexto.
    def snapshot_fields
      filtered_attributes.each_with_object({}) do |(attribute, value), result|
        result[attribute] = { "value" => mask(attribute, value) }
      end
    end

    # Em update salva apenas delta com old/new para reduzir ruido.
    # Atributo mascarado entra no delta (a troca de senha fica registrada), mas sem os valores.
    def update_fields
      filtered_previous_changes.each_with_object({}) do |(attribute, values), result|
        old_value, new_value = values
        result[attribute] = {
          "old_value" => mask(attribute, old_value),
          "new_value" => mask(attribute, new_value)
        }
      end
    end

    # Valor nulo continua nulo: mostra que o campo estava vazio sem revelar nada.
    def mask(attribute, value)
      return value if value.nil? || !masked_attributes.include?(attribute)

      configuration.mask_value
    end

    # Remove do snapshot os atributos que nao devem ser auditados.
    def filtered_attributes
      record.attributes.reject do |attribute, _value|
        ignored_attributes.include?(attribute)
      end
    end

    # Filtra as mudancas do ActiveRecord antes de montar o delta final.
    def filtered_previous_changes
      record.previous_changes.reject do |attribute, _value|
        ignored_attributes.include?(attribute)
      end
    end

    # Memoiza a lista final de ignored attributes para nao recalcular varias vezes.
    def ignored_attributes
      @ignored_attributes ||= model_config.effective_ignored_attributes(configuration)
    end

    def masked_attributes
      @masked_attributes ||= model_config.effective_masked_attributes(configuration)
    end
  end
end
