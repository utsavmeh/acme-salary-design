require "rails_helper"

RSpec.describe User do
  it "is valid with the factory defaults" do
    expect(build(:user)).to be_valid
  end

  it "stores a hash, never the password" do
    user = create(:user, password: "correct horse battery")
    expect(user.password_digest).not_to include("correct horse")
    expect(user.authenticate("correct horse battery")).to eq(user)
    expect(user.authenticate("wrong")).to be(false)
  end

  describe "username" do
    it "is stored trimmed and lowercase, and is unique regardless of case" do
      create(:user, username: "  Asha.Rao ")
      expect(described_class.last.username).to eq("asha.rao")
      expect(build(:user, username: "ASHA.RAO")).not_to be_valid
    end

    it "rejects spaces and too-short names" do
      expect(build(:user, username: "a b")).not_to be_valid
      expect(build(:user, username: "ab")).not_to be_valid
    end
  end

  describe "password rules" do
    it "needs at least 12 characters" do
      expect(build(:user, password: "short")).not_to be_valid
    end

    it "must not contain the username" do
      expect(build(:user, username: "asha.rao", password: "asha.rao-is-great")).not_to be_valid
    end

    it "must fit bcrypt's 72-byte limit" do
      expect(build(:user, password: "a" * 73)).not_to be_valid
    end
  end

  describe "roles" do
    it "accepts the known roles" do
      expect(build(:user, roles: %w[hr rate_manager auditor])).to be_valid
    end

    it "rejects an unknown role (there is no admin role)" do
      expect(build(:user, roles: ["admin"])).not_to be_valid
    end

    it "answers has_any_role? with symbols or strings" do
      user = build(:user, roles: ["hr"])
      expect(user.has_any_role?(:hr, :auditor)).to be(true)
      expect(user.has_any_role?(:auditor)).to be(false)
    end
  end

  describe "lockout" do
    let(:user) { create(:user) }

    it "locks the account after five wrong passwords in a row" do
      4.times { expect(user.record_failed_login!).to be(false) }
      expect(user.record_failed_login!).to be(true)
      expect(user.reload).to be_locked
    end

    it "unlocks by itself after the lock period" do
      5.times { user.record_failed_login! }
      travel_to(16.minutes.from_now) { expect(user.reload).not_to be_locked }
    end

    it "resets the counter on a successful login" do
      3.times { user.record_failed_login! }
      user.record_successful_login!
      expect(user.reload).to have_attributes(failed_attempts: 0, locked_until: nil)
      expect(user.last_login_at).to be_present
    end
  end

  it "can never be deleted" do
    user = create(:user)
    expect(user.destroy).to be(false)
    expect(described_class.count).to eq(1)
  end
end
