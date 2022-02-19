require 'sinatra'
require 'sinatra/reloader'
require 'redcarpet'
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

get '/:filename' do
  @files = load_files
  file_path = root + "/data/" + params[:filename]

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end