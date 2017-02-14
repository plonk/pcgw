require_relative '../jimson'

describe ViewHelpers do
  include ViewHelpers

  it 'bitrate_meter' do
    expect(bitrate_meter(0, 0)).to eq(0.1)
    expect(bitrate_meter(500, 0)).to eq(0.9)
    expect(bitrate_meter(0, 500)).to eq(0.1)
    expect(bitrate_meter(5000, 500)).to eq(0.9)
    expect(bitrate_meter(500, 500)).to eq(0.5)
  end
end
