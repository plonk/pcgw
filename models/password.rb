require 'digest/sha2'

class Password < ActiveRecord::Base
  belongs_to :user

  class << self
    def generate_salt
      set = [*'0'..'9',*'a'..'f']
      8.times.map { set.sample }.join
    end

    def for(plain_text)
      pass = Password.new
      pass.salt = Password.generate_salt
      pass.sha256sum = Digest::SHA256.hexdigest(plain_text + pass.salt)
      return pass
    end
  end

  def validate(plain_text)
    Digest::SHA256.hexdigest(plain_text + salt) == sha256sum
  end
end
