# frozen_string_literal: true
require "forwardable"
require "tmpdir"
require_relative "../lib/narou"
$stdout2 ||= $stdout
require_relative "../lib/commandbase"
require_relative "../lib/command/convert"

describe Command::Convert do
  it "変換失敗または例外時に既存の本を復元する" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "book.mobi")
      converter = described_class.new
      allow(Downloader).to receive(:novel_exists?).and_return(true)
      allow(NovelConverter).to receive(:extensions_of_converted_files).and_return([".mobi"])
      allow(Narou).to receive(:get_ebook_file_paths).and_return([path])
      File.binwrite(path, "old book")
      allow(converter).to receive(:convert_novel_main_impl) { File.binwrite(path, "partial") }
      converter.convert_novel_main(12, 1)
      expect(File.binread(path)).to eq("old book")
      allow(converter).to receive(:convert_novel_main_impl) { File.binwrite(path, "partial"); raise "failure" }
      expect { converter.convert_novel_main(12, 1) }.to raise_error("failure")
      expect(File.binread(path)).to eq("old book")
      allow(converter).to receive(:convert_novel_main_impl) do
        File.binwrite(path, "new book")
        converter.instance_variable_set(:@conversion_succeeded, true)
      end
      converter.convert_novel_main(12, 1)
      expect(File.binread(path)).to eq("new book")
    end
  end
end
