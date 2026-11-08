require "rails_helper"

RSpec.describe Auth::Roles do
  it "maps known groups to roles and ignores unknown ones" do
    expect(described_class.from_groups(%w[salary-hr salary-auditor staff])).to eq(%i[auditor hr])
  end

  it "gives no roles for no groups" do
    expect(described_class.from_groups(nil)).to eq([])
  end

  it "has no admin role" do
    expect(described_class::GROUP_TO_ROLE.values).not_to include(:admin)
  end
end
