# frozen_string_literal: true

require "test_helper"

class TestAuditLoggerAuditableFlow < Minitest::Test
  def test_creates_an_audit_log_after_create
    AuditLogger.configure do |config|
      config.changed_by_id_resolver = -> { 99 }
      config.changed_by_type_resolver = -> { "admin" }
      config.changed_by_other_resolver = -> { { name: "Joao", ip_remote: "10.0.0.1" } }
      config.uuid_resolver = -> { "session-123" }
      config.ip_resolver = -> { "127.0.0.1" }
    end

    record = SampleRecord.create!(name: "Joao", status: "active")
    audit_log = AuditLogger::AuditLog.last

    assert_equal "SampleRecord", audit_log.model_class_name
    assert_equal record.id.to_s, audit_log.id_object
    assert_equal "create", audit_log.action
    assert_equal "session-123", audit_log.uuid
    assert_equal 99, audit_log.changed_by_id
    assert_equal "admin", audit_log.changed_by_type
    assert_equal({ "name" => "Joao", "ip_remote" => "10.0.0.1" }, audit_log.changed_by_other)
    assert_equal "127.0.0.1", audit_log.ip_remote
    assert_equal "create", audit_log.audited_changes["type"]
    assert_equal "Joao", audit_log.audited_changes.dig("fields", "name", "value")
    assert_equal "Nome", audit_log.audited_changes_humanize.dig("fields", "name", "label")
    assert_equal 1, record.audit_logs.count
    assert_equal record.id.to_s, record.audit_logs.first.id_object
  end

  def test_creates_a_delta_audit_log_after_update
    record = SampleRecord.create!(name: "Joao", status: "active")

    record.update!(name: "Maria")
    audit_log = AuditLogger::AuditLog.last

    assert_equal "update", audit_log.action
    assert_equal "update", audit_log.audited_changes["type"]
    assert_equal ["name"], audit_log.audited_changes["fields"].keys
    assert_equal "Joao", audit_log.audited_changes.dig("fields", "name", "old_value")
    assert_equal "Maria", audit_log.audited_changes.dig("fields", "name", "new_value")
    assert_equal "Nome", audit_log.audited_changes_humanize.dig("fields", "name", "label")
  end

  def test_creates_a_snapshot_audit_log_after_destroy
    record = SampleRecord.create!(name: "Joao", status: "active")

    record.destroy!
    audit_log = AuditLogger::AuditLog.last

    assert_equal "destroy", audit_log.action
    assert_equal record.id.to_s, audit_log.id_object
    assert_equal "destroy", audit_log.audited_changes["type"]
    assert_equal "Joao", audit_log.audited_changes.dig("fields", "name", "value")
    assert_equal "active", audit_log.audited_changes.dig("fields", "status", "value")
  end

  def test_skips_update_audit_when_only_ignored_attributes_change
    AuditLogger.configure do |config|
      config.ignored_attributes = %i[created_at updated_at lock_version status]
    end

    record = SampleRecord.create!(name: "Joao", status: "active")

    assert_equal 1, AuditLogger::AuditLog.count

    record.update!(status: "inactive")

    assert_equal 1, AuditLogger::AuditLog.count
  end

  def test_uses_model_specific_i18n_scopes
    record = CustomSampleRecord.create!(name: "Joao", status: "active")
    audit_log = AuditLogger::AuditLog.last

    assert_equal "Status escola", audit_log.audited_changes_humanize.dig("fields", "status", "label")
    assert_equal "Nome", audit_log.audited_changes_humanize.dig("fields", "name", "label")
    assert_equal "CustomSampleRecord", audit_log.model_class_name
    assert_equal record.id.to_s, audit_log.id_object
  end

  def test_association_only_returns_logs_for_the_current_model
    sample = SampleRecord.create!(name: "Joao", status: "active")
    custom = CustomSampleRecord.create!(name: "Maria", status: "inactive")

    assert_equal 1, sample.audit_logs.count
    assert_equal 1, custom.audit_logs.count
    assert_equal "SampleRecord", sample.audit_logs.first.model_class_name
    assert_equal "CustomSampleRecord", custom.audit_logs.first.model_class_name
  end

  def test_uses_global_humanizer_when_present
    AuditLogger.configure do |config|
      config.humanizer = lambda do |_model_klass, attribute, old_value, new_value|
        {
          label: "Campo #{attribute}",
          old_value: old_value&.to_s&.upcase,
          new_value: new_value&.to_s&.upcase,
          value: new_value&.to_s&.upcase
        }
      end
    end

    record = SampleRecord.create!(name: "joao", status: "active")
    create_log = AuditLogger::AuditLog.last

    assert_equal "Campo name", create_log.audited_changes_humanize.dig("fields", "name", "label")
    assert_equal "JOAO", create_log.audited_changes_humanize.dig("fields", "name", "value")

    record.update!(status: "inactive")
    update_log = AuditLogger::AuditLog.last

    assert_equal "Campo status", update_log.audited_changes_humanize.dig("fields", "status", "label")
    assert_equal "ACTIVE", update_log.audited_changes_humanize.dig("fields", "status", "old_value")
    assert_equal "INACTIVE", update_log.audited_changes_humanize.dig("fields", "status", "new_value")
  end

  def test_allows_multiple_logs_with_the_same_uuid
    AuditLogger.configure do |config|
      config.uuid_resolver = -> { "shared-session-uuid" }
    end

    record = SampleRecord.create!(name: "Joao", status: "active")
    record.update!(status: "inactive")

    uuids = record.audit_logs.order(:id).pluck(:uuid)

    assert_equal ["shared-session-uuid", "shared-session-uuid"], uuids
  end

  def test_json_fields_are_read_back_as_hashes
    AuditLogger.configure do |config|
      config.changed_by_other_resolver = -> { { name: "Joao", role: "admin" } }
    end

    SampleRecord.create!(name: "Joao", status: "active")
    audit_log = AuditLogger::AuditLog.last

    assert_kind_of Hash, audit_log.changed_by_other
    assert_kind_of Hash, audit_log.audited_changes
    assert_kind_of Hash, audit_log.audited_changes_humanize
    assert_equal "Joao", audit_log.changed_by_other["name"]
    assert_equal "create", audit_log.audited_changes["type"]
  end

  def test_resolver_errors_do_not_break_audit_creation
    AuditLogger.configure do |config|
      config.changed_by_id_resolver = -> { raise "falha no contexto do usuario" }
      config.changed_by_type_resolver = -> { raise "falha no tipo" }
      config.changed_by_other_resolver = -> { raise "falha no metadata" }
      config.uuid_resolver = -> { raise "falha no uuid" }
      config.ip_resolver = -> { raise "falha no ip" }
    end

    SampleRecord.create!(name: "Joao", status: "active")
    audit_log = AuditLogger::AuditLog.last

    assert_nil audit_log.changed_by_id
    assert_nil audit_log.changed_by_type
    assert_equal({}, audit_log.changed_by_other)
    refute_nil audit_log.uuid
    assert_equal false, audit_log.uuid.empty?
    assert_nil audit_log.ip_remote
    assert_equal "create", audit_log.audited_changes["type"]
  end

  def test_humanizer_errors_fallback_to_default_translation
    AuditLogger.configure do |config|
      config.humanizer = ->(_model_klass, _attribute, _old_value, _new_value) { raise "falha no humanizer" }
    end

    SampleRecord.create!(name: "Joao", status: "active")
    audit_log = AuditLogger::AuditLog.last

    assert_equal "Nome", audit_log.audited_changes_humanize.dig("fields", "name", "label")
    assert_equal "Joao", audit_log.audited_changes_humanize.dig("fields", "name", "value")
  end
end
