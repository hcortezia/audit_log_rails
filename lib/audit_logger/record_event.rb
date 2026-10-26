# frozen_string_literal: true

module AuditLogger
  # Evento registrado a mao, para o que nao passa pelos callbacks do model:
  # pedido de reset de senha, login, alteracao em massa (update_all) etc.
  class RecordEvent
    def self.call(**options)
      new(**options).call
    end

    # fields usa o mesmo formato do log automatico: { "campo" => { "old_value" =>, "new_value" => } }
    # ou { "campo" => { "value" => } }. metadata guarda contexto livre (origem, quantidade...).
    def initialize(action:, record: nil, model_class_name: nil, id_object: nil, owner: nil, fields: {}, metadata: {})
      @action = action.to_s
      @record = record
      @model_class_name = model_class_name
      @id_object = id_object
      @owner = owner
      @fields = stringify(fields)
      @metadata = metadata || {}
    end

    def call
      AuditLogger.safely(record: record, action: action) { persist }
    end

    private

    attr_reader :action, :record, :model_class_name, :id_object, :owner, :fields, :metadata

    def persist
      payload = { "type" => action, "fields" => fields }
      payload["metadata"] = stringify(metadata) unless metadata.empty?

      AuditLogger::Persistence.create!(
        model_class_name: model_class_name || record&.class&.name || "AuditLogger::Event",
        id_object: id_object || record&.id,
        action: action,
        audited_changes: payload,
        audited_changes_humanize: humanize(payload),
        owner: owner_attributes
      )
    end

    # Com registro, reaproveita a humanizacao (labels e associacoes) da model dele.
    def humanize(payload)
      return payload unless record

      humanized = Humanizer.new(
        record: record, payload: payload, model_config: model_config, configuration: AuditLogger.configuration
      ).call
      humanized.merge(payload.slice("metadata"))
    end

    def owner_attributes
      return OwnerResolver.attributes_for(owner) if owner
      return OwnerResolver.call(record, model_config) if record

      {}
    end

    def model_config
      klass = record.class
      klass.respond_to?(:audit_logger_model_config) ? klass.audit_logger_model_config : ModelConfig.new
    end

    def stringify(hash)
      hash.to_h.each_with_object({}) do |(key, value), result|
        result[key.to_s] = value.is_a?(Hash) ? stringify(value) : value
      end
    end
  end
end
