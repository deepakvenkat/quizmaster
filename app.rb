require 'rubygems'
require 'sinatra'
require 'json'
require 'unirest'
require 'mongoid'

configure do
  Mongoid.load!("./config/mongoid.yml")
end
questions = [];

get '/' do
  content_type :json
  {message: "Hello World"}.to_json
end

get '/question' do
  response = Unirest::get "https://privnio-trivia.p.mashape.com/exec?v=1&method=getQuestions",
  headers: {
    "X-Mashape-Authorization" => "i7aV09XHCQCGH4pUNryAatVwMrlJaI3o"
  }
  content_type :json
  {questions: response.body}.to_json
end

get '/user/:username' do
  user = User.find_or_create_by(username: params[:username])
  content_type :json
  {user: user.username, score: user.score}.to_json
end

class User
  include Mongoid::Document
  field :username, type: String
  field :score, type: Integer, default: 0
  field :group, type: String
  validates_uniqueness_of :username
end