require '../test_helper'
require 'rake'

class RakeB13Import < ActiveSupport::TestCase

  describe 'b13:etl' do

    def setup
      ApplicationName::Application.load_tasks if Rake::Task.tasks.empty?
      Rake::Task["b13:etl"].invoke('B13_2022_Test.xlsx', 'Sheet_1', 'Mosaic ID')
    end

    it "Should import the b13" do
      expect(SendBulkMessageJob).to have_been_enqueued
      expect(Element.last.messages.pluck(:to_id)).to be == [u.id]
      refute_includes values, "thing I don't want"
      assert_includes values, "thing I do want"
    end

  end
end