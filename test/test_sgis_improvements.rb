# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class TestAuditLoggerSgisImprovements < Minitest::Test
  def test_masked_attribute_change_is_logged_without_values
    author = Author.create!(nome: "Ana", encrypted_password: "hash-antigo")

    author.update!(encrypted_password: "hash-novo")
    audit_log = AuditLogger::AuditLog.last

    assert_equal "update", audit_log.action
    assert_equal({ "old_value" => "[FILTRADO]", "new_value" => "[FILTRADO]" },
                 audit_log.audited_changes.dig("fields", "encrypted_password"))
    refute_includes audit_log.audited_changes.to_json, "hash-novo"
    refute_includes audit_log.audited_changes_humanize.to_json, "hash-antigo"
  end

  def test_masked_attribute_on_create_keeps_nil_as_nil
    Author.create!(nome: "Ana", encrypted_password: nil)

    assert_nil AuditLogger::AuditLog.last.audited_changes.dig("fields", "encrypted_password", "value")
  end

  def test_model_level_masked_attributes
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "sample_records"
      def self.name = "MaskedSample"
      include AuditLogger::Auditable
      auditable masked_attributes: [:status]
    end

    record = klass.create!(name: "Joao", status: "segredo")

    assert_equal "[FILTRADO]", AuditLogger::AuditLog.last.audited_changes.dig("fields", "status", "value")
    assert_equal "Joao", AuditLogger::AuditLog.last.audited_changes.dig("fields", "name", "value")
    assert record.persisted?
  end

  def test_failure_to_write_the_log_does_not_break_the_save
    erros = []
    AuditLogger.configure do |config|
      config.error_handler = ->(error, _record, action) { erros << [error.message, action] }
    end
    record = SampleRecord.create!(name: "Joao", status: "active")

    AuditLogger::AuditLog.stub(:create!, ->(*) { raise "banco indisponivel" }) do
      record.update!(name: "Maria")
    end

    assert_equal "Maria", record.reload.name
    assert_equal [["banco indisponivel", "update"]], erros
  end

  def test_raise_errors_lets_the_failure_through
    AuditLogger.configure { |config| config.raise_errors = true }
    record = SampleRecord.create!(name: "Joao", status: "active")

    AuditLogger::AuditLog.stub(:create!, ->(*) { raise "banco indisponivel" }) do
      assert_raises(RuntimeError) { record.update!(name: "Maria") }
    end
  end

  def test_owner_defaults_to_the_record_itself
    record = SampleRecord.create!(name: "Joao")
    audit_log = AuditLogger::AuditLog.last

    assert_equal "SampleRecord", audit_log.owner_type
    assert_equal record.id.to_s, audit_log.owner_id
  end

  def test_owner_association_groups_the_history
    author = Author.create!(nome: "Ana")
    document = Document.create!(title: "Ata", author: author)
    document.update!(title: "Ata revisada")

    history = AuditLogger::AuditLog.of_owner(author)

    assert_equal 3, history.count
    assert_equal %w[Document Document Author], history.map(&:model_class_name)
    assert_equal "update", history.first.action
  end

  def test_belongs_to_change_gets_the_associated_labels
    ana = Author.create!(nome: "Ana")
    bia = Author.create!(nome: "Bia")
    document = Document.create!(title: "Ata", author: ana)

    document.update!(author: bia)
    field = AuditLogger::AuditLog.last.audited_changes_humanize.dig("fields", "author_id")

    assert_equal ana.id, field["old_value"]
    assert_equal bia.id, field["new_value"]
    assert_equal "Ana", field["old_value_label"]
    assert_equal "Bia", field["new_value_label"]
  end

  def test_resolve_associations_can_be_turned_off
    AuditLogger.configure { |config| config.resolve_associations = false }
    ana = Author.create!(nome: "Ana")
    Document.create!(title: "Ata", author: ana)

    refute AuditLogger::AuditLog.last.audited_changes_humanize.dig("fields", "author_id").key?("value_label")
  end

  def test_record_event_with_a_record
    AuditLogger.configure { |config| config.changed_by_id_resolver = -> { 7 } }
    author = Author.create!(nome: "Ana")

    AuditLogger.record_event(
      action: "password_reset_requested",
      record: author,
      fields: { encrypted_password: { old_value: "[FILTRADO]", new_value: "[FILTRADO]" } },
      metadata: { origem: "esqueci_minha_senha" }
    )
    audit_log = AuditLogger::AuditLog.last

    assert_equal "password_reset_requested", audit_log.action
    assert_equal "Author", audit_log.model_class_name
    assert_equal author.id.to_s, audit_log.id_object
    assert_equal 7, audit_log.changed_by_id
    assert_equal "esqueci_minha_senha", audit_log.audited_changes.dig("metadata", "origem")
    assert_equal "esqueci_minha_senha", audit_log.audited_changes_humanize.dig("metadata", "origem")
    assert_equal ["Author", author.id.to_s], [audit_log.owner_type, audit_log.owner_id]
  end

  def test_record_event_without_a_record
    AuditLogger.record_event(action: "login_failed", model_class_name: "User", id_object: "12345678901",
                             metadata: { motivo: "senha" })
    audit_log = AuditLogger::AuditLog.last

    assert_equal "login_failed", audit_log.action
    assert_equal "User", audit_log.model_class_name
    assert_equal "12345678901", audit_log.id_object
    assert_nil audit_log.owner_type
  end

  def test_record_event_never_raises_by_default
    AuditLogger::AuditLog.stub(:create!, ->(*) { raise "banco indisponivel" }) do
      assert_nil AuditLogger.record_event(action: "login", model_class_name: "User", id_object: "1")
    end
  end
end
