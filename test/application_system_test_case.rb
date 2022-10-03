require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  # https://github.com/duleorlovic/minitest_rails/blob/main/test/application_system_test_case.rb
  # you can use bye bug, but it will stop rails so you can not navigate to other
  # pages or make another requests in chrome while testing
  def pause
    $stderr.write('Press CTRL+j or ENTER to continue') && $stdin.gets
  end
end
