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
    # Roda depois do commit: uma falha aqui nao pode virar erro da requisicao que ja gravou.
    def call
      AuditLogger.safely(record: record, action: action) { persist }
    end

    private

    attr_reader :record, :action, :configuration, :model_config

    def persist
      payload = ChangeExtractor.new(
        record: record,
        action: action,
        model_config: model_config,
        configuration: configuration
      ).call

      return if payload.fetch("fields", {}).empty?

      # Gera a versao amigavel do payload antes de persistir.
      humanized_payload = Humanizer.new(
        record: record,
        payload: payload,
        model_config: model_config,
        configuration: configuration
      ).call

      AuditLogger::Persistence.create!(
        model_class_name: record.class.name,
        id_object: record.id.to_s,
        action: action,
        audited_changes: payload,
        audited_changes_humanize: humanized_payload,
        owner: OwnerResolver.call(record, model_config)
      )
    end
  end
end
