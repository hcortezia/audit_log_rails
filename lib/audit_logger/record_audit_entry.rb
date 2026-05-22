# frozen_string_literal: true

module AuditLogger
  class RecordAuditEntry
    def self.call(record, action:)
      new(record, action: action).call
    end

    def initialize(record, action:)
      @record = record
      @action = action.to_s
      @configuration = AuditLogger.configuration
      @model_config = record.class.audit_logger_model_config
    end

    # Orquestra toda a montagem do log e persiste o resultado final.
    def call
      payload = ChangeExtractor.new(
        record: record,
        action: action,
        model_config: model_config,
        configuration: configuration
      ).call

      return if payload.fetch("fields", {}).empty?

      # Resolve o contexto do ator e gera a versao amigavel do payload antes de persistir.
      actor_context = ActorContextResolver.call(configuration)
      humanized_payload = Humanizer.new(
        record: record,
        payload: payload,
        model_config: model_config,
        configuration: configuration
      ).call

      AuditLog.create!(
        model_class_name: record.class.name,
        id_object: resolve_record_id,
        action: action,
        uuid: actor_context[:uuid].to_s,
        changed_by_id: actor_context[:changed_by_id],
        changed_by_type: actor_context[:changed_by_type],
        changed_by_other: actor_context[:changed_by_other],
        audited_changes: payload,
        audited_changes_humanize: humanized_payload,
        ip_remote: actor_context[:ip_remote],
        created_at: Time.current,
        updated_at: Time.current
      )
    end

    private

    attr_reader :record, :action, :configuration, :model_config

    # Normaliza o id como string para manter consistencia entre tipos de PK.
    def resolve_record_id
      record.id.to_s
    end
  end
end
