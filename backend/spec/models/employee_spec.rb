require "rails_helper"

RSpec.describe Employee do
  it "is valid with the factory defaults" do
    expect(build(:employee)).to be_valid
  end

  it "requires a unique employee number" do
    create(:employee, employee_number: "E1")
    expect(build(:employee, employee_number: "E1")).not_to be_valid
  end

  it "rejects a country that is not a 2-letter uppercase code" do
    expect(build(:employee, country: "india")).not_to be_valid
  end

  it "rejects an unknown status" do
    expect(build(:employee, status: "deleted")).not_to be_valid
  end

  describe "#assignment_on" do
    let(:employee) { create(:employee) }

    before do
      create(:assignment, employee:, department: "Support", job_title: "Agent", effective_from: Date.new(2020, 1, 1))
      create(:assignment, employee:, department: "Engineering", job_title: "Developer", effective_from: Date.new(2022, 6, 1))
    end

    it "returns the assignment in force on that date" do
      expect(employee.assignment_on(Date.new(2021, 12, 31)).department).to eq("Support")
      expect(employee.assignment_on(Date.new(2022, 6, 1)).department).to eq("Engineering")
    end

    it "returns nil before the first assignment" do
      expect(employee.assignment_on(Date.new(2019, 1, 1))).to be_nil
    end
  end
end
