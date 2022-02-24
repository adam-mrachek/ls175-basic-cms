require 'sinatra'
require 'sinatra/reloader'
require 'redcarpet'
require 'securerandom'
require 'yaml'
require 'pry'

configure do
  enable :sessions
  set :sessions_secret, SecureRandom.hex(64)
end

helpers do
  def admin?
    admins.has_key?(session[:username])
  end
end

def root
  File.expand_path("..", __FILE__)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_files
  pattern = File.join(data_path, "*")
  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

def error_for_nonexistent_file(file)
  if !File.file?(file)
    "#{File.basename(file)} does not exist."
  end
end

def error_for_filename(file)
  if !(1..100).cover?(file.length)
    "A name is required."
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)

  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def signed_in?
  session.key?(:username)
end

def require_sign_in
  unless signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def require_valid_username(username)
  if username.length <= 2
    session[:error] = "Username must be at least 2 characters long."
    redirect "/users/new"
  end
end

def require_valid_password(password)
  if password.length <= 8
    session[:error] = "Password must be at least 8 characters."
    redirect "/users/new"
  end
end
  
def require_admin
  unless admin?
    session[:error] = "You must be signed in as an admin to do that."
    redirect "/"
  end
end

def load_users
  users_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end
  YAML.load_file(users_path)
end

def admins
  file = File.join(root, "admins.yaml")
  YAML.load(File.open(file))
end


def user_exist?(username)
  users.has_key?(username.to_sym)
end

get '/' do
  @files = load_files
  users 
  erb :index, layout: :layout
end

get '/new' do
  require_sign_in
  erb :new
end

get '/users' do
  require_admin
  @users = load_users.keys.map(&:to_s)
  erb :"/users/index", layout: :layout
end

get '/users/new' do
  erb :"/users/new", layout: :layout
end

post '/users' do
  require_valid_username(params[:username].strip)
  require_valid_password(params[:password].strip)

  if !user_exist?(params[:username]) && (params[:password] == params[:password_confirm])
    new_user = { params[:username].to_sym => params[:password] }
    updated_users = load_users.merge(new_user)
    File.write("users.yaml", updated_users.to_yaml)
    session[:success] = "New user created."
    redirect "/users"
  elsif user_exist?(params[:username])
    session[:error] = "That username already exists."
    erb :"/users/new", layout: :layout
  elsif params[:password] != params[:password_confirm]
    session[:error] = "Passwords do not match. Please enter again."
    erb :"/users/new", layout: :layout
  end
end
  
post '/users/:user/delete' do
  user_hash = load_users
  user_hash.delete(params[:user].to_sym)
  File.write("users.yaml", user_hash.to_yaml)
  session[:success] = "User was deleted."
  redirect "/users"
end

post '/create' do
  require_sign_in
  new_file = params[:filename].strip
  
  error = error_for_filename(new_file)
  if error
   session[:error] = error
   status 422
   erb :new
  else
    File.open(File.join(data_path, new_file), "w")
    session[:success] = "#{new_file} was created."
    redirect "/"
  end
end

get '/:filename' do
  @files = load_files
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end

end

get '/:filename/edit' do
  require_sign_in
  file_path = File.join(data_path, params[:filename])
  if File.exist?(file_path)
    @file = File.read(file_path)
    erb :edit
  end
end

post '/:filename' do
  require_sign_in
  file_path = File.join(data_path, params[:filename])

  erb :new

  content = params[:file_content]

  File.write(file_path, content)
  
  session[:success] = "#{params[:filename]} has been updated"

  redirect "/"
end

post '/:filename/delete' do
  require_sign_in
  file_path = File.join(data_path, params[:filename])
  
  if File.exist?(file_path)
    File.delete(file_path)
    session[:success] = "#{params[:filename]} was deleted."
    redirect "/"
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get '/users/signin' do
  erb :"users/signin"
end

post '/users/signin' do
  if params[:username] == 'admin' && params[:password] == 'secret'
    session[:username] = params[:username]
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :"users/signin"
  end
end

post '/users/signout' do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end
