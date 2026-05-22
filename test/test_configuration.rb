# frozen_string_literal: true

require "test_helper"

class TestAuditLoggerConfiguration < Minitest::Test
  def test_exposes_default_configuration_values
    configuration = AuditLogger.configuration

    assert_nil configuration.changed_by_id_resolver
    assert_nil configuration.changed_by_type_resolver
    assert_instance_of Proc, configuration.changed_by_other_resolver
    assert_nil configuration.uuid_resolver
    assert_nil configuration.ip_resolver
    assert_equal true, configuration.humanize_by_default
    assert_equal ["activerecord.attributes", "attributes"], configuration.i18n_scopes
    assert_equal %i[created_at updated_at lock_version], configuration.ignored_attributes
    assert_nil configuration.humanizer
    assert_equal({}, configuration.changed_by_other_resolver.call)
  end

  def test_configure_updates_the_global_configuration
    AuditLogger.configure do |config|
      config.changed_by_id_resolver = -> { 10 }
      config.changed_by_type_resolver = -> { "admin" }
      config.changed_by_other_resolver = -> { { name: "Joao" } }
      config.uuid_resolver = -> { "session-uuid" }
      config.ip_resolver = -> { "127.0.0.1" }
      config.humanize_by_default = false
      config.i18n_scopes = ["school.student", "activerecord.attributes"]
      config.ignored_attributes = %i[updated_at deleted_at]
      config.humanizer = ->(_model_klass, attribute, _old_value, _new_value) { attribute.to_s.upcase }
    end

    configuration = AuditLogger.configuration

    assert_equal 10, configuration.changed_by_id_resolver.call
    assert_equal "admin", configuration.changed_by_type_resolver.call
    assert_equal({ name: "Joao" }, configuration.changed_by_other_resolver.call)
    assert_equal "session-uuid", configuration.uuid_resolver.call
    assert_equal "127.0.0.1", configuration.ip_resolver.call
    assert_equal false, configuration.humanize_by_default
    assert_equal ["school.student", "activerecord.attributes"], configuration.i18n_scopes
    assert_equal %i[updated_at deleted_at], configuration.ignored_attributes
    assert_equal "STATUS", configuration.humanizer.call(SampleRecord, :status, "a", "b")
  end

  def test_reset_configuration_restores_defaults
    AuditLogger.configure do |config|
      config.humanize_by_default = false
      config.i18n_scopes = ["custom.scope"]
    end

    AuditLogger.reset_configuration!
    configuration = AuditLogger.configuration

    assert_equal true, configuration.humanize_by_default
    assert_equal ["activerecord.attributes", "attributes"], configuration.i18n_scopes
  end

  def test_raises_when_callable_configuration_is_invalid
    error = assert_raises(AuditLogger::ConfigurationError) do
      AuditLogger.configure do |config|
        config.changed_by_id_resolver = "Current.user.id"
      end
    end

    assert_match(/changed_by_id_resolver/, error.message)
  end

  def test_raises_when_humanize_by_default_is_not_boolean
    error = assert_raises(AuditLogger::ConfigurationError) do
      AuditLogger.configure do |config|
        config.humanize_by_default = "true"
      end
    end

    assert_match(/humanize_by_default/, error.message)
  end

  def test_raises_when_i18n_scopes_is_invalid
    error = assert_raises(AuditLogger::ConfigurationError) do
      AuditLogger.configure do |config|
        config.i18n_scopes = [:invalid_scope]
      end
    end

    assert_match(/i18n_scopes/, error.message)
  end

  def test_raises_when_ignored_attributes_is_invalid
    error = assert_raises(AuditLogger::ConfigurationError) do
      AuditLogger.configure do |config|
        config.ignored_attributes = "updated_at"
      end
    end

    assert_match(/ignored_attributes/, error.message)
  end
end
