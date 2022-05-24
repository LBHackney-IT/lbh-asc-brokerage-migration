class InitialSchema < ActiveRecord::Migration[7.0]
  def change
    #
    # create_table :service_users do | t |
    #   t.integer :mosaic_id, null: false
    # end
    #
    # create_table :providers do | t |
    #   t.string :name, limit: 100, null: false
    #   t.integer :cedar_number, null: true
    #   t.integer :provider_type, default: 0
    # end
    #
    # execute <<~SQL
    # CREATE TYPE element_status AS ENUM (
    #   'in_progress',
    #   'awaiting_approval',
    #   'approved',
    #   'inactive',
    #   'active',
    #   'ended',
    #   'suspended'
    # );
    # SQL
    #
    # create_table :elements do | t |
    #   t.text :social_care_id
    #   t.references :element_type, index: true, null: true
    #   t.boolean :non_personal_budget, default: true
    #   t.references :provider, index: true, null: true
    #   t.text :details, default: '', null: false
    #   t.column :internal_status, 'element_status'
    #   t.date :updated_at
    #   t.references :related_element, class_name: 'Element', null: true
    #   t.date :start_date, null: true
    #   t.date :end_date, null: true
    #   t.string :name, limit: 100
    #   t.string :payee, limit: 80, null: true
    #   t.string :cost_centre, limit: 10, null: false
    #   t.string :cost_subjective, limit: 10, null: false
    #   t.string :cost_analysis, limit: 3, null: false, default: 'X'
    #   t.decimal :cost, null: true
    #   t.decimal :quantity, null: true
    #   t.string :cycle, limit: 10, null: true
    #   t.integer :unit, default: 0
    #   t.jsonb :monday, null: true
    #   t.jsonb :tuesday, null: true
    #   t.jsonb :wednesday, null: true
    #   t.jsonb :thursday, null: true
    #   t.jsonb :friday, null: true
    #   t.jsonb :saturday, null: true
    #   t.jsonb :sunday, null: true
    #   t.date :created_at
    # end
    #
    # create_table :element_types do | t |
    #   t.references :service, index: true
    #   t.string "name", limit: 100
    # end
    #
    # create_table :services do | t |
    #   t.references :parent, class_name: 'Service', null: true
    #   t.integer :position, default: 0
    #   t.string :name, limit: 100, null: false
    # end
    #
    # # these aren't imported from the B13 sources but are used as seeds
    #
    # execute <<~SQL
    # CREATE TYPE referral_status AS ENUM (
    #   'unassigned',
    #   'in_review',
    #   'assigned',
    #   'on_hold',
    #   'archived',
    #   'in_progress',
    #   'awaiting_approval',
    #   'approved'
    # );
    # SQL
    #
    # execute <<~SQL
    # CREATE TYPE workflow_type AS ENUM (
    #     'assessment',
    #     'review',
    #     'reassessment',
    #     'historic'
    # );
    # SQL
    #
    # create_table :referrals do | t |
    #   t.integer :workflow_id
    #   t.column :workflow_type, 'workflow_type', array: true
    #   t.text :resident_name
    #   t.text :assigned_to
    #   t.column :status, 'referral_status'
    #   t.date :created_at
    #   t.date :updated_at
    #   t.date :urgent_since
    #   t.integer :social_care_id
    #   t.text :form_name
    #   t.text :note
    #   t.string :primary_support_reason, limit: 100
    #   t.date :started_at
    # end
    #
    # execute <<~SQL
    # CREATE TYPE user_role AS ENUM (
    #    'brokerage_assistant',
    #    'broker',
    #    'approver',
    #    'care_charges_officer'
    # );
    # SQL
    #
    # create_table :users do | t |
    #   t.text :name
    #   t.text :email
    #   t.column :roles, 'user_role[]'
    #   t.boolean :is_active, null: false
    #   t.date :created_at
    #   t.date :updated_at
    # end

  end
end
