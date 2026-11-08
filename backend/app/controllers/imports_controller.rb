require "csv"

# The one-time Excel migration: upload -> review rejected rows and totals -> commit.
class ImportsController < ApplicationController
  MAX_FILE_BYTES = 20.megabytes

  before_action { require_role!(:hr) }
  before_action :load_batch, except: %i[index create]

  def index
    render json: { data: ImportBatch.order(id: :desc).limit(50).map { |b| present(b) } }
  end

  def create
    file = params[:file]
    raise AppErrors::BadRequest, "Attach the file as 'file'" unless file.respond_to?(:tempfile)
    raise AppErrors::BadRequest, "The file is larger than #{MAX_FILE_BYTES / 1.megabyte} MB" if file.size > MAX_FILE_BYTES

    batch = Imports::Stage.call(path: file.tempfile.path, filename: file.original_filename, uploaded_by: actor)
    render json: present(batch), status: :created
  end

  def show
    render json: present(@batch)
  end

  def rejected_rows
    rows = @batch.import_rows.rejected.order(:row_number)
    AuditLog.record(actor:, action: "import.rejected_rows_viewed", target: @batch, details: { count: rows.size })

    if request.format.csv?
      send_data rejected_csv(rows), type: "text/csv", filename: "import-#{@batch.id}-rejected-rows.csv"
    else
      render json: { data: rows.map { |r| { row_number: r.row_number, reasons: r.reasons, raw: r.raw } } }
    end
  end

  def reconciliation
    render json: Imports::Reconciliation.call(@batch)
  end

  def commit
    Imports::Commit.call(batch: @batch, actor:, confirm_rejected: params[:confirm_rejected_rows].to_s == "true")
    render json: present(@batch.reload)
  end

  private

  def load_batch = @batch = ImportBatch.find(params[:id])

  def present(batch)
    batch.slice(:id, :filename, :status, :total_rows, :accepted_rows, :rejected_rows, :uploaded_by, :committed_by, :committed_at, :created_at)
  end

  def rejected_csv(rows)
    columns = rows.flat_map { |r| r.raw.keys }.uniq
    CSV.generate do |csv|
      csv << ["row_number", "reasons", *columns]
      rows.each { |r| csv << [r.row_number, r.reasons.join(" | "), *columns.map { |c| CsvSanitizer.call(r.raw[c]) }] }
    end
  end
end
