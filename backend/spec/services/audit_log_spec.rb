require "rails_helper"

RSpec.describe AuditLog do
  def record(action = "employee.viewed", **extra)
    described_class.record(actor: "hr@acme.test", action:, **extra)
  end

  it "stores who did what to which record" do
    employee = create(:employee)
    event = record(target: employee, details: { filters: { country: "IN" } })

    expect(event).to have_attributes(actor: "hr@acme.test", action: "employee.viewed",
                                     target_type: "Employee", target_id: employee.id.to_s)
    expect(event.details).to eq("filters" => { "country" => "IN" })
  end

  it "links each event to the previous one" do
    first = record
    second = record

    expect(first.prev_hash).to eq(described_class::GENESIS_HASH)
    expect(second.prev_hash).to eq(first.event_hash)
  end

  describe ".verify" do
    it "accepts an untouched log, including an empty one" do
      expect(described_class.verify).to have_attributes(valid: true)
      3.times { record(details: { n: 1, nested: { b: 2, a: 1 } }) }
      expect(described_class.verify).to have_attributes(valid: true)
    end

    it "detects a changed row" do
      record
      tampered = record
      record
      AuditEvent.where(id: tampered.id).update_all(actor: "someone.else@acme.test")

      expect(described_class.verify).to have_attributes(valid: false, broken_at_id: tampered.id)
    end

    it "detects a deleted row" do
      record
      removed = record
      after = record
      AuditEvent.where(id: removed.id).delete_all

      expect(described_class.verify).to have_attributes(valid: false, broken_at_id: after.id)
    end
  end

  it "cannot be edited or destroyed through the model" do
    event = record
    expect { event.update!(actor: "x") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(event.destroy).to be(false)
  end
end
