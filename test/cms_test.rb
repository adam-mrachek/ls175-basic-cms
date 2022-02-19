ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require 'minitest/reporters'
require "rack/test"
require 'pry'
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'history.txt'
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_history_file
    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response["Content-Type"]
    assert_includes last_response.body, '1993 - Yukihiro Matsumoto dreams up Ruby.'
  end

  def test_document_not_found
    get '/doesnotexist.txt'

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "doesnotexist.txt does not exist."

    get "/"
    refute_includes last_response.body, "doesnotexist.txt does not exist."
  end

  def test_viewing_markdown_document
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end
end