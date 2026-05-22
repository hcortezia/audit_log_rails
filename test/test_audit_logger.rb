# frozen_string_literal: true

require "test_helper"

class TestAuditLogger < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::AuditLogger::VERSION
  end

  def test_connects_to_in_memory_database
    assert ActiveRecord::Base.connection.active?
  end

  def test_creates_the_minimum_test_schema
    assert ActiveRecord::Base.connection.table_exists?(:audit_logs)
    assert ActiveRecord::Base.connection.table_exists?(:sample_records)
  end

  def test_persists_records_with_active_record
    record = SampleRecord.create!(name: "Joao", status: "active")

    assert_equal 1, SampleRecord.count
    assert_equal "Joao", record.reload.name
  end
end
