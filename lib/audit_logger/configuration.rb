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
                  :masked_attributes,
                  :mask_value,
                  :humanizer,
                  :resolve_associations,
                  :raise_errors,
                  :error_handler

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
      # Atributos sensiveis: a alteracao e registrada, mas o valor vira mask_value.
      self.masked_attributes = default_masked_attributes
      self.mask_value = "[FILTRADO]"
      self.humanizer = nil
      # Troca o id de belongs_to pelo rotulo do registro associado no payload humanizado.
      self.resolve_associations = true
      # Por padrao a auditoria nunca derruba a operacao principal; nos testes vale ligar.
      self.raise_errors = false
      self.error_handler = nil

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

    # Senhas e tokens comuns em apps Rails (Devise, has_secure_password, tokens de API).
    def default_masked_attributes
      %i[password password_digest encrypted_password reset_password_token confirmation_token unlock_token]
    end
  end
end
