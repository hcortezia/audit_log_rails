# frozen_string_literal: true

module AuditLogger
  module Auditable
    extend ActiveSupport::Concern

    included do
      # Guarda a configuracao local da model sem poluir instancias.
      class_attribute :audit_logger_model_config, instance_accessor: false, default: ModelConfig.new
      # Evita registrar os mesmos callbacks mais de uma vez.
      class_attribute :audit_logger_callbacks_registered, instance_accessor: false, default: false
    end

    class_methods do
      # DSL principal da gem usada pelas models do projeto cliente.
      def auditable(**options)
        # Mantem a configuracao por model isolada do restante da gem.
        self.audit_logger_model_config = ModelConfig.new(**options)

        # Expoe uma associacao simples para consultar os logs desta model.
        define_audit_logs_association!

        return if audit_logger_callbacks_registered

        # Usa callbacks de commit para evitar auditoria falsa em caso de rollback.
        after_create_commit { AuditLogger::RecordAuditEntry.call(self, action: :create) }
        after_update_commit { AuditLogger::RecordAuditEntry.call(self, action: :update) }
        after_destroy_commit { AuditLogger::RecordAuditEntry.call(self, action: :destroy) }

        self.audit_logger_callbacks_registered = true
      end

      private

      # Define a associacao apenas uma vez para evitar conflitos com reload da classe.
      def define_audit_logs_association!
        return if reflect_on_association(:audit_logs)

        has_many :audit_logs,
                 ->(record) { where(model_class_name: record.class.name) },
                 class_name: "AuditLogger::AuditLog",
                 foreign_key: :id_object,
                 primary_key: :id
      end
    end
  end
end
