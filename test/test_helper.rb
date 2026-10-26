# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "audit_logger"
require "active_record"
require "logger"
require "i18n"

require "minitest/autorun"

# Configura um banco SQLite em memoria para os testes da gem.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger.level = Logger::WARN

# Cria um schema minimo para exercitar persistencia e callbacks via ActiveRecord.
ActiveRecord::Schema.define do
  suppress_messages do
    create_table :audit_logs, force: true do |t|
      t.string :model_class_name, null: false
      t.string :id_object, null: false
      t.string :action, null: false
      t.string :uuid, null: false
      t.bigint :changed_by_id
      t.string :changed_by_type
      t.text :changed_by_other
      t.text :audited_changes
      t.text :audited_changes_humanize
      t.string :ip_remote
      t.string :owner_type
      t.string :owner_id
      t.datetime :deleted_at
      t.timestamps null: false
    end

    create_table :authors, force: true do |t|
      t.string :nome
      t.string :encrypted_password
      t.timestamps null: false
    end

    create_table :documents, force: true do |t|
      t.string :title
      t.references :author
      t.timestamps null: false
    end

    create_table :sample_records, force: true do |t|
      t.string :name
      t.string :status
      t.timestamps null: false
    end
  end
end

I18n.available_locales = %i[en pt-BR]
I18n.enforce_available_locales = false
I18n.backend.store_translations(:en, {
  activerecord: {
    attributes: {
      sample_record: {
        name: "Nome",
        status: "Situacao"
      },
      custom_sample_record: {
        name: "Nome",
        status: "Status customizado"
      }
    }
  },
  attributes: {
    status: "Status"
  },
  school: {
    custom_sample_record: {
      status: "Status escola"
    }
  }
})

class SampleRecord < ActiveRecord::Base
  include AuditLogger::Auditable

  auditable
end

class CustomSampleRecord < ActiveRecord::Base
  self.table_name = "sample_records"

  include AuditLogger::Auditable

  auditable humanize: true,
            i18n_scopes: ["school", "activerecord.attributes"]
end

# Autor com senha (mascarada) e documento que agrupa o historico no autor.
class Author < ActiveRecord::Base
  include AuditLogger::Auditable

  auditable
end

class Document < ActiveRecord::Base
  include AuditLogger::Auditable

  belongs_to :author, optional: true

  auditable owner: :author
end

class Minitest::Test
  def setup
    # Limpa os dados entre testes para evitar acoplamento entre cenarios.
    AuditLogger::AuditLog.delete_all
    SampleRecord.delete_all
    Document.delete_all
    Author.delete_all
    AuditLogger.reset_configuration!
    I18n.locale = :en
  end
end
