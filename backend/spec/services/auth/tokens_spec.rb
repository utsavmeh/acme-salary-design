require "rails_helper"

RSpec.describe Auth::Tokens do
  let(:user) { create(:user) }

  it "gives back the user for a token it issued" do
    expect(described_class.verify(described_class.issue(user))).to eq(user)
  end

  it "rejects a token signed with another key" do
    forged = JWT.encode({ sub: user.id, pwd: described_class.fingerprint(user), exp: 1.hour.from_now.to_i }, "attacker", "HS256")
    expect { described_class.verify(forged) }.to raise_error(AppErrors::Unauthorized)
  end

  it "rejects an expired token" do
    token = described_class.issue(user, now: 9.hours.ago)
    expect { described_class.verify(token) }.to raise_error(AppErrors::Unauthorized)
  end

  it "accepts a token just before it expires" do
    token = described_class.issue(user, now: 7.hours.ago)
    expect(described_class.verify(token)).to eq(user)
  end

  it "rejects garbage and unsigned tokens" do
    expect { described_class.verify("nonsense") }.to raise_error(AppErrors::Unauthorized)
    unsigned = JWT.encode({ sub: user.id, pwd: described_class.fingerprint(user), exp: 1.hour.from_now.to_i }, nil, "none")
    expect { described_class.verify(unsigned) }.to raise_error(AppErrors::Unauthorized)
  end

  it "stops working the moment the user is deactivated" do
    token = described_class.issue(user)
    user.update!(status: "deactivated")
    expect { described_class.verify(token) }.to raise_error(AppErrors::Unauthorized)
  end

  it "stops working after the password changes" do
    token = described_class.issue(user)
    user.update!(password: "a brand new passphrase")
    expect { described_class.verify(token) }.to raise_error(AppErrors::Unauthorized)
  end

  it "sees role changes immediately because roles are not stored in the token" do
    token = described_class.issue(user)
    user.update!(roles: [ "auditor" ])
    expect(described_class.verify(token).roles).to eq([ "auditor" ])
  end
end
