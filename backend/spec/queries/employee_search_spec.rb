require "rails_helper"

RSpec.describe EmployeeSearch do
  let(:today) { Date.new(2025, 6, 1) }

  let!(:asha) { create(:employee, name: "Asha Rao", employee_number: "E100", country: "IN") }
  let!(:ben)  { create(:employee, name: "Ben Smith", employee_number: "E200", country: "US") }
  let!(:cara) { create(:employee, name: "Cara 100% Smith", employee_number: "E300", country: "US", status: "inactive") }

  before do
    create(:assignment, employee: asha, department: "Engineering", job_title: "Developer", effective_from: Date.new(2020, 1, 1))
    create(:assignment, employee: ben, department: "Sales", job_title: "Manager", effective_from: Date.new(2020, 1, 1))
    create(:assignment, employee: ben, department: "Engineering", job_title: "Manager", effective_from: Date.new(2026, 1, 1)) # future
  end

  def names(params) = described_class.new(params, today:).call.map(&:name)

  it "returns everyone ordered by name when there are no filters" do
    expect(names({})).to eq([ "Asha Rao", "Ben Smith", "Cara 100% Smith" ])
  end

  it "matches text against name or employee number, ignoring case" do
    expect(names(q: "asha")).to eq([ "Asha Rao" ])
    expect(names(q: "e200")).to eq([ "Ben Smith" ])
  end

  it "treats % in the text as a literal character" do
    expect(names(q: "100%")).to eq([ "Cara 100% Smith" ])
  end

  it "filters by country and status" do
    expect(names(country: "us")).to eq([ "Ben Smith", "Cara 100% Smith" ])
    expect(names(country: "US", status: "inactive")).to eq([ "Cara 100% Smith" ])
  end

  it "filters by the department held on the given day, not a future one" do
    expect(names(department: "Engineering")).to eq([ "Asha Rao" ])
    expect(names(department: "Sales")).to eq([ "Ben Smith" ])
  end

  it "combines filters with AND" do
    expect(names(department: "Engineering", country: "US")).to be_empty
  end

  it "ignores unknown parameters" do
    expect(described_class.new({ evil: "1; drop table", country: "IN" }).applied_filters).to eq(country: "IN")
  end
end
