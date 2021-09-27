# # frozen_string_literal: true
#
# require 'selenium-webdriver'
# args = ['--headless', '--disable-gpu', '--no-sandbox', '--disable-extensions', '--disable-dev-shm-usage']
# options = Selenium::WebDriver::Chrome::Options.new(args: args)
# driver = Selenium::WebDriver.for(:chrome, options: options)
#
# driver.navigate.to "https://de.vestiairecollective.com/my-account.shtml"
# wait = Selenium::WebDriver::Wait.new(:timeout => 20)
# name = wait.until {
#   element_1 = driver.find_element(:class, "firstHeading")
# }
# puts name.text