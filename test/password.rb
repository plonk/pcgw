require_relative '../models/password'

describe Password do
  it 'salt を生成できる' do
    salt = Password.generate_salt
    expect(salt.size).to eq(8)
  end
end
