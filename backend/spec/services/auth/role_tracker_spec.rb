require "rails_helper"

RSpec.describe Auth::RoleTracker do
  def identity(*roles) = Auth::Identity.new(email: "hr@acme.test", roles:)

  it "records and audits the first time a person is seen" do
    described_class.observe(identity(:hr))

    expect(RoleSnapshot.count).to eq(1)
    expect(AuditEvent.last).to have_attributes(action: "roles.first_seen", actor: "hr@acme.test")
  end

  it "does nothing when the roles are unchanged" do
    described_class.observe(identity(:hr))
    expect { described_class.observe(identity(:hr)) }.not_to change { [RoleSnapshot.count, AuditEvent.count] }
  end

  it "audits a change of roles with the old and new values" do
    described_class.observe(identity(:hr))
    described_class.observe(identity(:hr, :rate_manager))

    event = AuditEvent.last
    expect(event.action).to eq("roles.changed")
    expect(event.details).to eq("from" => ["hr"], "to" => %w[hr rate_manager])
  end
end
