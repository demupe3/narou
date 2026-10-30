# frozen_string_literal: true

require "forwardable"
require_relative "../lib/narou"
$stdout2 ||= $stdout
require_relative "../lib/downloader"

describe Downloader do
  it "タイトル解析失敗時に404として凍結しない" do
    downloader = described_class.allocate
    setting = double("setting")
    stream = double("stream")
    downloader.instance_variable_set(:@setting, setting)
    downloader.instance_variable_set(:@stream, stream)
    allow(downloader).to receive(:get_toc_source).and_return("<html></html>")
    allow(setting).to receive(:multi_match)
    allow(NovelInfo).to receive(:load).and_return({"title" => nil})
    expect(stream).to receive(:error).with(/タイトルを取得できません/)
    expect(downloader).not_to receive(:database)
    expect(downloader.get_latest_table_of_contents(nil)).to eq(false)
  end

  it "呼び出し元が要求した場合は解析失敗を例外として返す" do
    downloader = described_class.allocate
    setting = double("setting")
    downloader.instance_variable_set(:@setting, setting)
    allow(downloader).to receive(:get_toc_source).and_return("<html></html>")
    allow(setting).to receive(:multi_match)
    allow(NovelInfo).to receive(:load).and_return({"title" => ""})
    expect { downloader.get_latest_table_of_contents(nil, through_error: true) }.to raise_error(Downloader::DownloaderParseError)
  end
end
