require "rails_helper"

RSpec.describe CsvSanitizer do
  it "prefixes text that a spreadsheet would run as a formula" do
    [ "=1+1", "+1", "-1", "@SUM(A1)", "\tcmd" ].each do |text|
      expect(described_class.call(text)).to start_with("'")
    end
  end

  it "leaves normal text alone" do
    expect(described_class.call("Asha Rao")).to eq("Asha Rao")
    expect(described_class.call(nil)).to eq("")
  end
end
