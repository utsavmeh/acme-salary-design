require "rails_helper"

RSpec.describe Users::Manager do
  subject(:manager) { described_class.new(operator: "ops") }

  def last_event = AuditEvent.order(:id).last

  describe "#create" do
    it "creates a user with a one-time password that must be changed" do
      created = manager.create(username: "Asha.Rao", roles: %w[hr rate_manager])

      expect(created.user).to have_attributes(username: "asha.rao", roles: %w[hr rate_manager], must_change_password: true, status: "active")
      expect(created.user.authenticate(created.temporary_password)).to be_truthy
      expect(created.temporary_password.length).to be >= 16
    end

    it "audits who did it and which roles were given, without the password" do
      created = manager.create(username: "asha.rao", roles: [ "hr" ])

      expect(last_event).to have_attributes(action: "user.created", actor: "cli:ops", target_id: created.user.id.to_s)
      expect(last_event.details).to eq("roles" => [ "hr" ])
      expect(AuditEvent.all.map { |e| e.attributes.to_s }.join).not_to include(created.temporary_password)
    end

    it "refuses an unknown role and creates nothing" do
      expect { manager.create(username: "asha.rao", roles: [ "admin" ]) }.to raise_error(ActiveRecord::RecordInvalid)
      expect([ User.count, AuditEvent.count ]).to eq([ 0, 0 ])
    end

    it "refuses a duplicate username" do
      manager.create(username: "asha.rao", roles: [])
      expect { manager.create(username: "ASHA.RAO", roles: []) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#set_roles" do
    let!(:user) { create(:user, username: "asha.rao", roles: [ "hr" ]) }

    it "replaces the roles and audits the old and new ones" do
      manager.set_roles("asha.rao", %w[auditor])

      expect(user.reload.roles).to eq([ "auditor" ])
      expect(last_event.details).to eq("from" => [ "hr" ], "to" => [ "auditor" ])
    end

    it "fails clearly for an unknown user" do
      expect { manager.set_roles("ghost", []) }.to raise_error(AppErrors::BadRequest, /No user named 'ghost'/)
    end
  end

  describe "#reset_password" do
    let!(:user) { create(:user, username: "asha.rao", password: "correct horse battery") }

    it "sets a new one-time password, forces a change, clears any lock, and signs out old sessions" do
      5.times { user.record_failed_login! }
      old_token = Auth::Tokens.issue(user.reload)

      reset = manager.reset_password("asha.rao")

      expect(user.reload).to have_attributes(must_change_password: true, failed_attempts: 0, locked_until: nil)
      expect(user.authenticate("correct horse battery")).to be(false)
      expect(user.authenticate(reset.temporary_password)).to be_truthy
      expect { Auth::Tokens.verify(old_token) }.to raise_error(AppErrors::Unauthorized)
      expect(last_event.action).to eq("user.password_reset")
    end
  end

  describe "#deactivate and #activate" do
    let!(:user) { create(:user, username: "asha.rao") }

    it "deactivates without deleting, and blocks sign-in and existing sessions" do
      token = Auth::Tokens.issue(user)
      manager.deactivate("asha.rao")

      expect(user.reload.status).to eq("deactivated")
      expect { Auth::Tokens.verify(token) }.to raise_error(AppErrors::Unauthorized)
      expect(last_event.action).to eq("user.deactivated")
    end

    it "can be reversed" do
      manager.deactivate("asha.rao")
      manager.activate("asha.rao")
      expect(user.reload.status).to eq("active")
    end

    it "does not write an audit event when nothing changes" do
      expect { manager.activate("asha.rao") }.not_to change(AuditEvent, :count)
    end
  end

  it "#unlock clears a lockout" do
    user = create(:user, username: "asha.rao")
    5.times { user.record_failed_login! }

    manager.unlock("asha.rao")

    expect(user.reload).not_to be_locked
    expect(last_event.action).to eq("user.unlocked")
  end

  it "#list returns users by name" do
    create(:user, username: "zed.user")
    create(:user, username: "amy.user")
    expect(manager.list.map(&:username)).to eq(%w[amy.user zed.user])
  end
end
