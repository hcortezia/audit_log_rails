# frozen_string_literal: true

module AuditLogger
  # Grava uma linha em audit_logs com o contexto do ator (usuario, uuid, ip).
  # Compartilhado pelo log automatico (auditable) e pelos eventos manuais (record_event).
  module Persistence
    def self.create!(model_class_name:, id_object:, action:, audited_changes:, audited_changes_humanize:, owner: {})
      actor_context = ActorContextResolver.call(AuditLogger.configuration)
      now = Time.current
      attributes = {
        model_class_name: model_class_name,
        id_object: id_object.to_s,
        action: action.to_s,
        uuid: actor_context[:uuid].to_s,
        changed_by_id: actor_context[:changed_by_id],
        changed_by_type: actor_context[:changed_by_type],
        changed_by_other: actor_context[:changed_by_other],
        audited_changes: audited_changes,
        audited_changes_humanize: audited_changes_humanize,
        ip_remote: actor_context[:ip_remote],
        created_at: now,
        updated_at: now
      }
      # Instalacoes da 0.1.x ainda sem as colunas de dono continuam funcionando.
      attributes.merge!(owner) if AuditLog.owner_columns?

      AuditLog.create!(attributes)
    end
  end
end
