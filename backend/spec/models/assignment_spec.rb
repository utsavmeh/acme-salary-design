require "rails_helper"

RSpec.describe Assignment do
  it "does not allow two assignments starting on the same date for one employee" do
    employee = create(:employee)
    create(:assignment, employee:, effective_from: Date.new(2021, 1, 1))
    expect(build(:assignment, employee:, effective_from: Date.new(2021, 1, 1))).not_to be_valid
  end
end
