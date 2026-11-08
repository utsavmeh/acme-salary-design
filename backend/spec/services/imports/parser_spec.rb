require "rails_helper"

RSpec.describe Imports::Parser do
  it "reads a CSV into rows numbered as in the file (header is line 1)" do
    rows = described_class.call(csv_path([ import_row, import_row("employee_number" => "E2") ]), "x.csv")

    expect(rows.map(&:number)).to eq([ 2, 3 ])
    expect(rows.first.values).to include("employee_number" => "E1", "base_pay" => "1000")
  end

  it "skips completely blank lines but keeps line numbers" do
    path = csv_path([ import_row, {}, import_row("employee_number" => "E3") ])
    expect(described_class.call(path, "x.csv").map(&:number)).to eq([ 2, 4 ])
  end

  it "normalises header names" do
    path = csv_path([ { "Employee Number" => "E1" } ], headers: [ "Employee Number" ])
    expect(described_class.call(path, "x.csv").first.values.keys).to eq([ "employee_number" ])
  end

  it "reads an Excel .xlsx file, including real Excel dates and numeric cells" do
    rows = described_class.call(file_fixture("salaries.xlsx").to_s, "salaries.xlsx")

    expect(rows.size).to eq(1)
    expect(rows.first.values).to include("hire_date" => "2020-01-01", "effective_from" => "2024-01-01", "base_pay" => "1000", "net" => "850")
  end

  it "refuses other file types" do
    expect { described_class.call(csv_path([ import_row ]), "x.pdf") }.to raise_error(AppErrors::BadRequest, /Only .csv and .xlsx/)
  end

  it "refuses an empty file and a broken .xlsx" do
    empty = Tempfile.new([ "empty", ".csv" ]).tap(&:close)
    expect { described_class.call(empty.path, "e.csv") }.to raise_error(AppErrors::BadRequest, /empty/)

    junk = Tempfile.new([ "junk", ".xlsx" ]).tap { |f| f.write("not a zip"); f.close }
    expect { described_class.call(junk.path, "junk.xlsx") }.to raise_error(AppErrors::BadRequest)
  end
end
