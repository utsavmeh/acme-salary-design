# Creates salary records and corrections. Records are never edited: a correction is a new
# version for the same effective date. Each write and its audit entry share one transaction.
#
# The audit entry names what changed but does not copy pay amounts, so people who may read
# the audit log (auditors) do not get to see salaries through it.
class SalaryRecordWriter
  RECORD_FIELDS = %i[currency country base_pay gross net].freeze

  def initialize(actor:)
    @actor = actor
  end

  # attrs: currency, base_pay, gross, net, effective_from, optional country, deductions: [{label:, amount:}]
  def create(employee, attrs)
    attrs = attrs.to_h.symbolize_keys
    effective_from = attrs[:effective_from]

    SalaryRecord.transaction do
      if effective_from.present? && employee.salary_records.exists?(effective_from:)
        raise AppErrors::Conflict, "A salary record starting #{effective_from} already exists. Correct it instead of adding another."
      end

      record = build(employee, attrs.merge(country: attrs[:country].presence || employee.country), version: 1)
      record.save!
      AuditLog.record(actor: @actor, action: "salary_record.created", target: record,
                      details: { employee_id: employee.id, effective_from: record.effective_from, version: 1 })
      record
    end
  rescue ActiveRecord::RecordNotUnique
    raise AppErrors::Conflict, "A salary record for that date was just added by someone else."
  end

  # Fields left out of `attrs` keep their previous values (including the deduction lines).
  def correct(record, attrs)
    attrs = attrs.to_h.symbolize_keys.except(:effective_from)

    SalaryRecord.transaction do
      latest = SalaryRecord.where(employee_id: record.employee_id, effective_from: record.effective_from).order(:version).last
      if latest.id != record.id
        raise AppErrors::Conflict, "This record was already corrected (version #{latest.version} exists). Reload and try again."
      end

      merged = previous_values(record).merge(attrs)
      corrected = build(record.employee, merged, version: record.version + 1)
      corrected.save!
      AuditLog.record(actor: @actor, action: "salary_record.corrected", target: corrected,
                      details: { employee_id: record.employee_id, effective_from: record.effective_from,
                                 version: corrected.version, changed: changed_fields(record, corrected) })
      corrected
    end
  rescue ActiveRecord::RecordNotUnique
    raise AppErrors::Conflict, "Someone else corrected this record at the same time. Reload and try again."
  end

  private

  def build(employee, attrs, version:)
    record = employee.salary_records.build(attrs.slice(*RECORD_FIELDS, :effective_from).merge(version:, created_by: @actor))
    Array(attrs[:deductions]).each do |line|
      line = line.to_h.symbolize_keys
      record.deduction_lines.build(label: line[:label], amount: line[:amount])
    end
    record
  end

  def previous_values(record)
    record.slice(*RECORD_FIELDS, :effective_from).symbolize_keys.merge(
      deductions: record.deduction_lines.map { |l| { label: l.label, amount: l.amount } }
    )
  end

  def changed_fields(old, new)
    fields = RECORD_FIELDS.select { |f| old[f] != new[f] }
    fields << :deductions if old.deduction_lines.map { |l| [l.label, l.amount] } != new.deduction_lines.map { |l| [l.label, l.amount] }
    fields
  end
end
