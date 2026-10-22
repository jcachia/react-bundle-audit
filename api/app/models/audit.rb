class Audit < ApplicationRecord
  MAX_LOCKFILE_BYTES = 1.megabyte

  # Text pasted into a browser field arrives with CRLFs, a BOM, or stray
  # surrounding whitespace; bundler-audit expects a clean Gemfile.lock.
  normalizes :lockfile, with: ->(text) {
    text.delete_prefix("﻿").gsub(/\r\n?/, "\n").strip.then { |t| t.empty? ? t : "#{t}\n" }
  }

  validates :lockfile, presence: true
  validates :lockfile, length: {maximum: MAX_LOCKFILE_BYTES}
  validate :lockfile_is_parseable, if: -> { lockfile.present? }

  private

  # LockfileParser is lenient with arbitrary text, so an empty spec list is
  # the signal that this isn't a Gemfile.lock.
  def lockfile_is_parseable
    if Bundler::LockfileParser.new(lockfile).specs.empty?
      errors.add(:lockfile, "doesn't look like a Gemfile.lock (no gems found under GEM specs)")
    end
  rescue Bundler::BundlerError
    errors.add(:lockfile, "could not be parsed (merge conflict markers or a corrupt file?)")
  end
end
