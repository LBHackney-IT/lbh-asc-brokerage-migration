require 'test_helper'
require_relative '../../lib/tasks/b13_transformations'

class TransformRejectIfMosaicNotIntTest < ActiveSupport::TestCase
  setup do
    @mosaic_col = 'mosaic'
    @rejections = Hash.new
    @transform = TransformRejectIfMosaicNotInt.new mosaic_col: @mosaic_col, rejections: @rejections
  end

  test "rejects if not int" do
    assert_nil @transform.process( { "#{@mosaic_col}": 'abc', 'foo': 'bar'})
  end

  test "confimed user is not deleted" do
    assert_equal @confimed_user, User.find_by(email: "john@appleseed.com")
  end
end

class TransformCleanUnitsTest < ActiveSupport::TestCase
end

class TransformElementFNCCTest < ActiveSupport::TestCase
end

# replaces any weird unicode non breaking spaces with a plain ' '
class TransformCleanNBSPTest < ActiveSupport::TestCase
end

class TransformRemoveHTMLTest < ActiveSupport::TestCase
end

class TransformProviderCedarTest < ActiveSupport::TestCase
end

class TransformElementCostTypeTest < ActiveSupport::TestCase
end

class TransformRejectParseCostCentreTest < ActiveSupport::TestCase
end

class TransformAddDefaultsTest < ActiveSupport::TestCase
end