require 'rubygems'
require 'sinatra'
require 'json'
require 'unirest'
require 'mongoid'
require 'sinatra/config_file'
require 'yaml'
require 'autoinc'

configure do
  config_file 'config/keys.yml'
  Mongoid.load!("./config/mongoid.yml")
end


####HTTP Auth########
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  username == settings.basic_auth["username"] && password == settings.basic_auth["password"]
end

########Routes#########
get '/' do
  content_type :json
  {message: "Hello World"}.to_json
end

get '/question' do
  response = Question.get_question
  content_type :json
  {questions: response}.to_json
end

get '/user/:username' do
  user = User.find_or_create_by(username: params[:username])
  content_type :json
  {user: user.username, score: user.score}.to_json
end

post '/answer' do
  user = User.find_or_create_by(username: params[:username]);
  question = Question.find_by(uid: params[:uid])
  if question.nil? || !question["current"]
    content_type :json
    {error: {incorrect_question: "question not valid"}}.to_json
  end
  if question["answer"] == params[:answer]
    user.inc(:score, 1)
    question.update_attributes(current: false, answered_by: user.username)
    content_type :json
    {success: {correct_answer: "Corrent answer", user: user.username, socre: user.score}}
  else
    {error: {incorrect_answer: "incorrect answer"}}
  end
end

#######Models#############
class User
  include Mongoid::Document
  field :username, type: String
  field :score, type: Integer, default: 0
  field :group, type: String
  validates_uniqueness_of :username
end

class Question
  include Mongoid::Document
  include Mongoid::Autoinc
  field :question, type: String
  field :answer, type: String
  field :uid, type: Integer
  field :current, type: Boolean, default: true
  field :difficulty, type: Integer
  field :category, type: String
  field :answered_by, type: String
  validates_uniqueness_of :uid
  increments :uid, seed: 1000

  def self.get_question
    question = Question.where(current: true).first
    if question.nil?
      question = QuestionStore.retrieve_questions()
    end
    Question.where(_id: question["_id"]).update({'$set'=>{current: false}})
    return question
  end
end

class QuestionStore
  include Mongoid::Document
  def self.get_question
    questions = QuestionStore.where(used: false).first
    if questions.nil? || questions.result.length == 0
      questions = retrieve_questions
    end
    update_question_store(questions)
    question = Question.create(questions["result"][0])
    return question
  end

  def self.retrieve_questions
    mashape = YAML.load_file('config/keys.yml')["mashape"]

    response = Unirest::get(mashape["url"],
      headers: {
        "X-Mashape-Authorization" => mashape["authorization"]
      }
    )
    if response.code == 200
      questions = response.body
      questions["used"] = false
      QuestionStore.collection.insert(questions)
      update_questions(response.body["result"])
      return Question.where({current: true})
    end
  end

  def self.update_questions(questions)
    questions.each do |question|
      Question.create(question)
    end
    return
  end
end