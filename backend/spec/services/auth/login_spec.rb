require "rails_helper"

RSpec.describe Auth::Login do
  let!(:user) { create(:user, username: "asha", password: "correct horse battery") }

  def login(username: "asha", password: "correct horse battery") = described_class.call(username:, password:, ip: "10.0.0.1")
  def actions = AuditEvent.order(:id).pluck(:action)

  it "returns the user and audits a successful login" do
    expect(login).to eq(user)
    expect(user.reload.last_login_at).to be_present
    expect(AuditEvent.last).to have_attributes(action: "login.succeeded", actor: "asha")
    expect(AuditEvent.last.details).to eq("ip" => "10.0.0.1")
  end

  it "ignores case and surrounding spaces in the username" do
    expect(login(username: "  ASHA ")).to eq(user)
  end

  it "gives the same message for a wrong password and an unknown user" do
    wrong = begin; login(password: "nope"); rescue AppErrors::Unauthorized => e; e.message; end
    unknown = begin; login(username: "ghost"); rescue AppErrors::Unauthorized => e; e.message; end

    expect(wrong).to eq(unknown)
    expect(wrong).to eq(described_class::MESSAGE)
  end

  it "audits failures, including the attempted username and the reason" do
    expect { login(password: "nope") }.to raise_error(AppErrors::Unauthorized)
    expect { login(username: "ghost") }.to raise_error(AppErrors::Unauthorized)

    expect(AuditEvent.order(:id).map { |e| [ e.action, e.actor, e.details["reason"] ] })
      .to eq([ [ "login.failed", "asha", "wrong_password" ], [ "login.failed", "ghost", "unknown_user" ] ])
  end

  it "never writes the password into the audit log" do
    expect { login(password: "super secret guess") }.to raise_error(AppErrors::Unauthorized)
    expect(AuditEvent.all.map { |e| e.attributes.to_s }.join).not_to include("super secret guess")
  end

  it "locks the account after five wrong passwords, even for the right password afterwards" do
    5.times { expect { login(password: "nope") }.to raise_error(AppErrors::Unauthorized) }

    expect { login }.to raise_error(AppErrors::Unauthorized)
    expect(actions.last(2)).to eq(%w[login.locked login.blocked])
  end

  it "lets the user in again once the lock has expired" do
    5.times { expect { login(password: "nope") }.to raise_error(AppErrors::Unauthorized) }
    travel_to(16.minutes.from_now) { expect(login).to eq(user) }
  end

  it "refuses a deactivated user even with the right password" do
    user.update!(status: "deactivated")
    expect { login }.to raise_error(AppErrors::Unauthorized)
    expect(AuditEvent.last.details["reason"]).to eq("deactivated")
  end

  it "handles a blank username and password" do
    expect { login(username: "", password: "") }.to raise_error(AppErrors::Unauthorized)
    expect(AuditEvent.last.actor).to eq("(blank)")
  end
end
