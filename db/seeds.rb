# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

[
  {
    id: 1,
    workflow_id: 'cku85l88s023016l0kwriqb6d',
    workflow_type: 'assessment',
    social_care_id: 4,
    resident_name: 'Joey Tribbiani',
    assigned_to: nil,
    status: 'unassigned',
    created_at: '2020-01-01 00:00:00',
    updated_at: '2020-01-01 00:00:00',
    urgent_since: nil,
    form_name: 'Care act assessment',
    note: 'This is a note from the social worker',
    primary_support_reason: nil,
    started_at: nil
  },
  {
    id: 3,
    workflow_id: 'cku3w06ax000615mikaap8776',
    workflow_type: 'assessment',
    social_care_id: 3,
    resident_name: 'Monica Geller',
    assigned_to: nil,
    status: 'in_review',
    created_at: '2020-01-06 00:00:00',
    updated_at: '2020-01-06 00:00:00',
    urgent_since: nil,
    form_name: 'Care act assessment',
    note: 'This is a note from the social worker',
    primary_support_reason: nil,
    started_at: nil
  },
  {
    id: 4,
    workflow_id: 'cku5fu4p103781bjq84cqrlsg',
    workflow_type: 'assessment',
    social_care_id: 3,
    resident_name: 'Chandler Bing',
    assigned_to: 'dan.bate@hackney.gov.uk',
    status: 'in_review',
    created_at: '2020-01-08 00:00:00',
    updated_at: '2020-01-08 00:00:00',
    urgent_since: nil,
    form_name: 'Care act assessment',
    note: 'This is a note from the social worker',
    primary_support_reason: nil,
    started_at: nil
  },
  {
    id: 5,
    workflow_id: 'cktvj0sz1003116mgxcns3ug3',
    workflow_type: 'assessment',
    social_care_id: 1,
    resident_name: 'Phoebe Buffay',
    assigned_to: 'jane.doe@hackney.gov.uk',
    status: 'in_review',
    created_at: '2020-01-14 00:00:00',
    updated_at: '2020-01-14 00:00:00',
    urgent_since: nil,
    form_name: 'Care act assessment',
    note: 'This is a note from the social worker',
    primary_support_reason: nil,
    started_at: nil
  },
  {
    id: 6,
    workflow_id: 'ckze7zad0078008jrt3fyq2pq',
    workflow_type: 'assessment',
    social_care_id: 1,
    resident_name: 'Ross Geller',
    assigned_to: 'joe.bloggs@hackney.gov.uk',
    status: 'in_review',
    created_at: '2020-01-12 00:00:00',
    updated_at: '2020-01-12 00:00:00',
    urgent_since: nil,
    form_name: 'Care act assessment',
    note: 'This is a note from the social worker',
    primary_support_reason: nil,
    started_at: nil
  },
  {
    id: 2,
    workflow_id: 'cku2g425500691cmowrdbjj40',
    workflow_type: 'assessment',
    social_care_id: 1,
    resident_name: 'Ms. Chanandler Bing',
    assigned_to: 'jane.doe@hackney.gov.uk',
    status: 'in_review',
    created_at: '2022-01-04 00:00:00',
    updated_at: '2022-04-12 09:06:39.841737',
    urgent_since: '2020-01-04 00:00:00',
    form_name: 'Care act assessment',
    note: 'This is a note from the social worker',
    primary_support_reason: nil,
    started_at: nil
  },
].each { |r| Referral.create r }

[
  {
    id: 1,
    email: 'kevin.sedgley@hackney.gov.uk',
    roles: 'approver',
    name: 'Kelvin Smogley',
    is_active: true
  }
].each { | u | User.create u }