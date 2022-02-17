require 'sinatra'
require 'sinatra/reloader'
require 'pry'

configure do
  enable :sessions
  set :sessions_secret, 'secret'
end

# root = File.expand_path("..", __FILE__)

def root
  File.expand_path("..", __FILE__)
end

def load_files
  Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
end

def error_for_nonexistent_file(file)
  if !File.file?(file)
    "#{File.basename(file)} does not exist."
  end
end

get '/' do
  @files = load_files

  erb :index
end

get '/:filename' do
  @files = load_files
  file_path = root + "/data/" + params[:filename]

  error = error_for_nonexistent_file(file_path)
  if error
    session[:error] = error

    redirect "/"
  else
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  end
end