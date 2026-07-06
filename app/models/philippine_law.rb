class PhilippineLaw < ApplicationRecord
  SOURCES = %w[seeded llm_discovered].freeze

  scope :active,   -> { where(is_verified: true) }
  scope :seeded,   -> { where(source: "seeded") }
  scope :discovered, -> { where(source: "llm_discovered") }

  validates :abbreviation, presence: true, uniqueness: true
  validates :pattern,      presence: true
  validates :full_name,    presence: true
  validates :description,  presence: true
  validates :source,       inclusion: { in: SOURCES }

  # Test the stored pattern against a string
  def matches?(text)
    Regexp.new(pattern, Regexp::IGNORECASE).match?(text)
  end

  # Return the compiled Regexp
  def to_regexp
    Regexp.new(pattern, Regexp::IGNORECASE)
  end

  def increment_usage!
    increment!(:usage_count)
  end
end