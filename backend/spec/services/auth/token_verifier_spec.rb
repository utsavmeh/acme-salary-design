require "rails_helper"

RSpec.describe Auth::TokenVerifier do
  subject(:verifier) { described_class.new(secret: "test-secret") }

  def token(secret: "test-secret", **payload)
    JWT.encode(payload, secret, "HS256")
  end

  it "returns the email and roles for a valid token" do
    identity = verifier.verify(token(email: "Hr@Acme.test", groups: %w[salary-hr other], exp: 1.hour.from_now.to_i))

    expect(identity.email).to eq("hr@acme.test")
    expect(identity.roles).to eq([:hr])
  end

  it "rejects a token signed with another key" do
    forged = token(secret: "attacker", email: "a@acme.test", groups: ["salary-hr"], exp: 1.hour.from_now.to_i)
    expect { verifier.verify(forged) }.to raise_error(AppErrors::Unauthorized)
  end

  it "rejects an expired token" do
    expired = token(email: "a@acme.test", groups: ["salary-hr"], exp: 1.minute.ago.to_i)
    expect { verifier.verify(expired) }.to raise_error(AppErrors::Unauthorized)
  end

  it "rejects a token without an expiry" do
    expect { verifier.verify(token(email: "a@acme.test", groups: ["salary-hr"])) }.to raise_error(AppErrors::Unauthorized)
  end

  it "rejects a token without an email" do
    expect { verifier.verify(token(groups: ["salary-hr"], exp: 1.hour.from_now.to_i)) }.to raise_error(AppErrors::Unauthorized)
  end

  it "rejects garbage and an unsigned (alg none) token" do
    expect { verifier.verify("not-a-token") }.to raise_error(AppErrors::Unauthorized)
    unsigned = JWT.encode({ email: "a@acme.test", groups: ["salary-hr"], exp: 1.hour.from_now.to_i }, nil, "none")
    expect { verifier.verify(unsigned) }.to raise_error(AppErrors::Unauthorized)
  end
end
