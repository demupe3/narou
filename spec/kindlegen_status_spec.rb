# frozen_string_literal: true
require "forwardable"
require "tmpdir"
require_relative "../lib/narou"
$stdout2 ||= $stdout
require_relative "../lib/novelconverter"

describe NovelConverter do
  it "終了コードと生成されたMOBIを検証する" do
    Dir.mktmpdir do |dir|
      epub = File.join(dir, "book.epub")
      mobi = File.join(dir, "book.mobi")
      File.write(epub, "test")
      allow(Narou).to receive(:kindlegen_path).and_return(epub)
      io = double("log", print: nil, puts: nil, error: nil)
      status = double("process", exited?: true, exitstatus: 3)
      allow(Helper::AsyncCommand).to receive(:exec).and_return([+"", +"", status])
      expect(described_class.epub_to_mobi(epub, stream_io: io)).to eq(:error)
      allow(status).to receive(:exitstatus).and_return(0)
      expect(described_class.epub_to_mobi(epub, stream_io: io)).to eq(:error)
      allow(Helper::AsyncCommand).to receive(:exec) do
        File.binwrite(mobi, "\0" * 60 + "BOOKMOBI" + "data")
        [+"", +"", status]
      end
      expect(described_class.epub_to_mobi(epub, stream_io: io)).to eq(:success)
      allow(Helper::AsyncCommand).to receive(:exec).and_return([+"", +"", status])
      expect(described_class.epub_to_mobi(epub, stream_io: io)).to eq(:error)
    end
  end
end
