require "digest"

# Writes and verifies the audit log.
#
# Every event stores the hash of the event before it, forming a chain. Changing or deleting
# an old row breaks the chain, which `verify` detects. Call `record` inside the same database
# transaction as the action being audited so the action and its log entry succeed or fail together.
module AuditLog
  GENESIS_HASH = ("0" * 64).freeze
  LOCK_KEY = 7_315_001 # arbitrary constant: serialises writers so the chain has no forks

  Verification = Struct.new(:valid, :broken_at_id, keyword_init: true)

  module_function

  def record(actor:, action:, target: nil, details: {})
    AuditEvent.transaction do
      AuditEvent.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
      previous = AuditEvent.order(:id).last
      attributes = {
        occurred_at: Time.current.utc.round(6), actor:, action:,
        target_type: target&.class&.name, target_id: target&.id&.to_s,
        details: JSON.parse(details.to_json), prev_hash: previous&.event_hash || GENESIS_HASH
      }
      AuditEvent.create!(attributes.merge(event_hash: digest(attributes)))
    end
  end

  # Walks the whole chain in order and reports the first broken event, if any.
  def verify
    expected_prev = GENESIS_HASH
    AuditEvent.order(:id).find_each do |event|
      stored = event.attributes.symbolize_keys.slice(:occurred_at, :actor, :action, :target_type, :target_id, :details, :prev_hash)
      unless event.prev_hash == expected_prev && event.event_hash == digest(stored)
        return Verification.new(valid: false, broken_at_id: event.id)
      end

      expected_prev = event.event_hash
    end
    Verification.new(valid: true)
  end

  def digest(attributes)
    canonical = [
      attributes[:prev_hash], attributes[:occurred_at].utc.iso8601(6), attributes[:actor], attributes[:action],
      attributes[:target_type], attributes[:target_id], canonical_json(attributes[:details])
    ].join("|")
    Digest::SHA256.hexdigest(canonical)
  end

  # JSON with sorted keys, so the same data always gives the same text (the database may reorder keys).
  def canonical_json(value)
    case value
    when Hash then "{#{value.sort_by { |k, _| k.to_s }.map { |k, v| "#{k.to_s.to_json}:#{canonical_json(v)}" }.join(',')}}"
    when Array then "[#{value.map { |v| canonical_json(v) }.join(',')}]"
    else value.to_json
    end
  end
end
