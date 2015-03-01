require_relative '../models/genre'

describe Genre, 'コマンドを含む文字列で初期化された時' do
  it '正しくコマンド部を判断する' do
    genre = Genre.new('sp?@@@Game')
    expect(genre.proper).to eq('Game')
  end

  it 'リスナー数非表示のコマンドを理解する' do
    g1 = Genre.new('sp?Game')
    expect(g1.hide_listener_count?).to eq true

    g2 = Genre.new('spGame')
    expect(g2.hide_listener_count?).to eq false
  end

  it '聴衆限定のコマンドを理解する' do
    g1 = Genre.new('sp@Game')
    expect(g1.minimum_bandwidth).to eq '@'

    g2 = Genre.new('sp@@Game')
    expect(g2.minimum_bandwidth).to eq '@@'

    g3 = Genre.new('sp@@@Game')
    expect(g3.minimum_bandwidth).to eq '@@@'
  end

  it 'ネームスペースを理解する' do
    g = Genre.new('spSECRET:Game')
    expect(g.namespace).to eq 'SECRET'
  end

end
