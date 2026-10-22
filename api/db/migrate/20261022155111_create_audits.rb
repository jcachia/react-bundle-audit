class CreateAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :audits do |t|
      t.text :lockfile, null: false
      t.jsonb :results, null: false, default: []
      t.jsonb :warnings, null: false, default: []
      t.datetime :advisory_db_updated_at

      t.timestamps
    end
  end
end
