class AuditsController < ApplicationController
  def create
    audit = Audit.new(lockfile: params[:lockfile].to_s)

    if audit.valid?
      AuditRunner.new(audit).call
      render json: audit_json(audit), status: :created
    else
      render json: {errors: audit.errors.full_messages}, status: :unprocessable_content
    end
  rescue AdvisoryDatabase::Unavailable => e
    render json: {errors: [e.message]}, status: :service_unavailable
  end

  def show
    render json: audit_json(Audit.find(params[:id]))
  end

  private

  def audit_json(audit)
    audit.as_json(only: %i[id results warnings advisory_db_updated_at created_at])
  end
end
