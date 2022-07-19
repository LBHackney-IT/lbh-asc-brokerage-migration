require 'test_helper'

class EtlDropTest < ActiveSupport::TestCase
  setup do
    @confirmed_user = User.create(email: "john@appleseed.com", confirmed_at: Time.now)
    @unconfirmed_user = User.create(email: "jane@doe.com", confirmed_at: nil)
    MyApplication::Application.load_tasks
    Rake::Task['users:remove_unconfirmed'].invoke
  end

  test "unconfirmed user is deleted" do
    assert_nil User.find_by(email: "jane@doe.com")
  end

  test "confimed user is not deleted" do
    assert_equal @confimed_user, User.find_by(email: "john@appleseed.com")
  end
end

class ImportCleanedElementNamesTest < ActiveSupport::TestCase
  setup do
    @confirmed_user = User.create(email: "john@appleseed.com", confirmed_at: Time.now)
    @unconfirmed_user = User.create(email: "jane@doe.com", confirmed_at: nil)
    MyApplication::Application.load_tasks
    Rake::Task['users:remove_unconfirmed'].invoke
  end

  test "unconfirmed user is deleted" do
    assert_nil User.find_by(email: "jane@doe.com")
  end

  test "confimed user is not deleted" do
    assert_equal @confimed_user, User.find_by(email: "john@appleseed.com")
  end
end

class EtlProviderTest < ActiveSupport::TestCase
  setup do
    @confirmed_user = User.create(email: "john@appleseed.com", confirmed_at: Time.now)
    @unconfirmed_user = User.create(email: "jane@doe.com", confirmed_at: nil)
    MyApplication::Application.load_tasks
    Rake::Task['users:remove_unconfirmed'].invoke
  end

  test "unconfirmed user is deleted" do
    assert_nil User.find_by(email: "jane@doe.com")
  end

  test "confimed user is not deleted" do
    assert_equal @confimed_user, User.find_by(email: "john@appleseed.com")
  end
end


class EtlProviderTest < ActiveSupport::TestCase
  setup do
    @confirmed_user = User.create(email: "john@appleseed.com", confirmed_at: Time.now)
    @unconfirmed_user = User.create(email: "jane@doe.com", confirmed_at: nil)
    MyApplication::Application.load_tasks
    Rake::Task['users:remove_unconfirmed'].invoke
  end

  test "unconfirmed kjn is deleted" do
    assert_nil User.find_by(email: "jane@doe.com")
  end

  test "confimed user iskjbnnot deleted" do
    assert_equal @confimed_user, User.find_by(email: "john@appleseed.com")
  end
end

class EtlProcessProviderClarificationsTest < ActiveSupport::TestCase
  setup do
    @confirmed_user = User.create(email: "john@appleseed.com", confirmed_at: Time.now)
    @unconfirmed_user = User.create(email: "jane@doe.com", confirmed_at: nil)
    MyApplication::Application.load_tasks
    Rake::Task['users:remove_unconfirmed'].invoke
  end

  test "unconfirmed user is deleted" do
    assert_nil User.find_by(email: "jane@doe.com")
  end

  test "confimed user is not deleted" do
    assert_equal @confimed_user, User.find_by(email: "john@appleseed.com")
  end
end

class EtlFindProviderClustersTest < ActiveSupport::TestCase

end

class EtlImportProvidersIntoDbTest < ActiveSupport::TestCase

end

class EtlImportProvidersIntoDbTest < ActiveSupport::TestCase

end

class EtlTest < ActiveSupport::TestCase

end
