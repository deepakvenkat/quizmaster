class User
  include Mongoid::Document
  field :username, type: String
  field :score, type: Integer, default: 0
  field :group, type: String
  validate_uniqueness_of :username

  def find_or_create(username)
  end
end