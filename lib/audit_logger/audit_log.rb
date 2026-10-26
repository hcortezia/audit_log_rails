# frozen_string_literal: true

module AuditLogger
  class AuditLog < ActiveRecord::Base
    self.table_name = "audit_logs"

    JSON_FIELDS = %w[changed_by_other audited_changes audited_changes_humanize].freeze

    # Historico de um agregado: tudo o que tem o registro como dono, do mais recente ao mais antigo.
    scope :of_owner, lambda { |owner|
      where(OwnerResolver.attributes_for(owner)).order(created_at: :desc, id: :desc)
    }

    # As colunas de dono chegaram na 0.2.0; a migration de upgrade cria as duas.
    def self.owner_columns?
      column_names.include?("owner_type") && column_names.include?("owner_id")
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      false
    end

    # Mantem compatibilidade entre bancos nativos JSON/JSONB e colunas texto sem
    # depender de conexao ativa no carregamento da classe.
    JSON_FIELDS.each do |field_name|
      define_method("#{field_name}=") do |value|
        super(normalize_json_assignment(field_name, value))
      end

      define_method(field_name) do
        deserialize_json_value(super())
      end
    end

    private

    # Em bancos sem suporte nativo a JSON, persiste como string JSON.
    def normalize_json_assignment(field_name, value)
      return value if value.nil? || json_like_column?(field_name)
      return value if value.is_a?(String)

      JSON.generate(value)
    end

    # Ao ler colunas texto, reconstrói o Hash/Array original para o restante da gem.
    def deserialize_json_value(value)
      return value unless value.is_a?(String)

      JSON.parse(value)
    rescue JSON::ParserError
      value
    end

    # A verificacao do tipo fica em runtime, quando a conexao ja deve estar disponivel.
    def json_like_column?(field_name)
      self.class.type_for_attribute(field_name.to_s).type.in?(%i[json jsonb])
    rescue ActiveRecord::ConnectionNotDefined, ActiveRecord::NoDatabaseError
      false
    end
  end
end
