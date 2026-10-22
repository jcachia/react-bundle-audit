require "test_helper"

class AuditTest < ActiveSupport::TestCase
  context "Audit" do
    should validate_presence_of(:lockfile)

    should "reject text that is not a Gemfile.lock" do
      audit = Audit.new(lockfile: "just some words")

      refute audit.valid?
      assert_match(/doesn't look like a Gemfile.lock/, audit.errors[:lockfile].to_sentence)
    end

    should "reject a lockfile with merge conflict markers" do
      audit = Audit.new(lockfile: "<<<<<<< HEAD\n#{VULNERABLE_LOCKFILE}=======\n>>>>>>> branch\n")

      refute audit.valid?
      assert audit.errors[:lockfile].any?
    end

    should "reject a lockfile over the size limit" do
      audit = Audit.new(lockfile: "x" * (Audit::MAX_LOCKFILE_BYTES + 1))

      refute audit.valid?
      assert audit.errors.of_kind?(:lockfile, :too_long)
    end

    should "accept a valid lockfile" do
      assert Audit.new(lockfile: VULNERABLE_LOCKFILE).valid?
    end

    should "normalize CRLFs, a BOM, and surrounding whitespace" do
      pasted = "﻿\n  #{VULNERABLE_LOCKFILE.gsub("\n", "\r\n")}\r\n\r\n"
      audit = Audit.create!(lockfile: pasted)

      assert_equal VULNERABLE_LOCKFILE.strip + "\n", audit.lockfile
    end
  end
end
