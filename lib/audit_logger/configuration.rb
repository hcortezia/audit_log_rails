# frozen_string_literal: true

module AuditLogger
  class Configuration
    # Cada accessor representa um ponto configuravel da gem.
    attr_accessor :changed_by_id_resolver,
                  :changed_by_type_resolver,
                  :changed_by_other_resolver,
                  :uuid_resolver,
                  :ip_resolver,
                  :humanize_by_default,
                  :i18n_scopes,
                  :ignored_attributes,
                  :humanizer

    def initialize
      reset!
    end

    # Restaura todos os defaults para um estado conhecido e previsivel.
    def reset!
      # Defaults simples para que a gem funcione sem obrigar configuracao imediata.
      self.changed_by_id_resolver = nil
      self.changed_by_type_resolver = nil
      self.changed_by_other_resolver = -> { {} }
      self.uuid_resolver = nil
      self.ip_resolver = nil
      self.humanize_by_default = true
      self.i18n_scopes = default_i18n_scopes
      self.ignored_attributes = default_ignored_attributes
      self.humanizer = nil

      self
    end

    private

    # Escopos padrao usados para localizar labels de atributos.
    def default_i18n_scopes
      ["activerecord.attributes", "attributes"]
    end

    # Campos normalmente ruidosos que nao agregam valor na auditoria.
    def default_ignored_attributes
      %i[created_at updated_at lock_version]
    end
  end
end
