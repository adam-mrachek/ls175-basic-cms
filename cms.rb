require 'sinatra'
require 'sinatra/reloader'
require 'redcarpet'
require 'pry'

configure do
  enable :sessions
  set :sessions_secret, 'secret'
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

get '/' do
  @files = load_files

  erb :index
end

get '/new' do
  erb :new
end

post '/create' do
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
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    @file = File.read(file_path)
    erb :edit
  end
end

post '/:filename' do
  file_path = File.join(data_path, params[:filename])

  content = params[:file_content]

  File.write(file_path, content)
  
  session[:success] = "#{params[:filename]} has been updated"

  redirect "/"
end