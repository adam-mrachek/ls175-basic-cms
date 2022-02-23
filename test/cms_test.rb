ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require 'minitest/reporters'
require "rack/test"
require "fileutils"
require 'pry'
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def session
    last_request.env["rack.session"]
  end
  
  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"
    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
    assert_includes last_response.body, "New Document</a>"
  end

  def test_history_file
    create_document "history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby."
    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response["Content-Type"]
    assert_includes last_response.body, '1993 - Yukihiro Matsumoto dreams up Ruby.'
  end

  def test_document_not_found
    get '/doesnotexist.txt'

    assert_equal 302, last_response.status
    assert_equal "doesnotexist.txt does not exist.", session[:error]
  end

  def test_viewing_markdown_document
    create_document "about.md", "<h1>Ruby is...</h1>"
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_document
    create_document "changes.txt"
    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_editing_document_signed_out
    create_document "changes.txt"
    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_updating_document
    post "/changes.txt", { file_content: "updated content" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated", session[:success]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "updated content"
  end

  def test_updating_document_signed_out
    post "/changes.txt"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end
  
  def test_view_new_document_form
     get "/new", {}, admin_session

     assert_equal 200, last_response.status
     assert_includes last_response.body, "Add a new document"
     assert_includes last_response.body, %q(<button type="submit">Create)
  end
  
  def test_view_new_document_form_signed_out
    get "/new"

    assert 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end
  
  def test_create_new_document
    post "/create", { filename: "test.txt" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:success]
    
    get "/"
    assert_includes last_response.body, "test.txt"
  end
  
  def test_empty_name
    post "/create", { filename: "" }, admin_session

    assert_equal 422, last_response.status
    
    assert_includes last_response.body, "A name is required."
  end
  
  def test_delete_document
    create_document "test.txt"
    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "test.txt"

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt was deleted.", session[:success]

    get last_response["Location"]
    
    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_delete_document_signed_out
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end
  
  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post 'users/signin', username: "admin", password: "secret"
    
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end
  
  def test_signin_with_bad_credentials
    post 'users/signin', username: "", password: ""
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end
  

  def test_signout
    post '/users/signin', username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    post '/users/signout'
    assert_equal "You have been signed out.", session[:success] 
    get last_response["Location"]

    assert_includes last_response.body, "Sign In"
    assert_nil session[:username]
  end
end