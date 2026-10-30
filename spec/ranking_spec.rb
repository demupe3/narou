# frozen_string_literal: true
require_relative "../lib/narou/ranking"

describe Narou::Ranking do
  before { described_class.instance_variable_set(:@cache, {}) }

  it "順位を維持して作品情報を結合し、管理済みを表示する" do
    ranks = [{"rank" => 1, "ncode" => "N1234AA", "pt" => 200},
             {"rank" => 2, "ncode" => "N2345BB", "pt" => 100}]
    details = [{"allcount" => 2}, {"ncode" => "N2345BB", "title" => "第二作", "end" => 0},
               {"ncode" => "N1234AA", "title" => "第一作", "writer" => "著者", "end" => 1}]
    expect(described_class).to receive(:request).with(described_class::RANK_URL, hash_including("rtype" => "20261027-w")).once.and_return(ranks)
    expect(described_class).to receive(:request).with(described_class::NOVEL_URL, hash_including("ncode" => "n1234aa-n2345bb")).once.and_return(details)
    result = described_class.fetch(date: "2026-10-27", kind: "w", registered: ["N1234AA"])
    expect(result.map { |r| r["title"] }).to eq(["第一作", "第二作"])
    expect(result.map { |r| r["registered"] }).to eq([true, false])
    # Cached metadata must not cache the user's management state.
    expect(described_class.fetch(date: "2026-10-27", kind: "w", registered: [])[0]["registered"]).to eq(false)
  end

  it "形式が不正なNコードを排除し、空なら詳細APIを呼ばない" do
    expect(described_class).to receive(:request).once.and_return([{"ncode" => "../../etc/passwd"}])
    expect(described_class.fetch(date: "2026-10-27", kind: "d")).to eq([])
  end

  it "日付・種別の制約をAPIにアクセスする前に検証する" do
    expect(described_class).not_to receive(:request)
    [["2026-10-28", "w"], ["2026-10-02", "m"], ["bad", "d"], ["2026-10-27", "x"]].each do |date, kind|
      expect { described_class.fetch(date: date, kind: kind) }.to raise_error(ArgumentError)
    end
  end

  it "詳細情報が取得できない作品を順位付きで残す" do
    allow(described_class).to receive(:request).and_return([{"rank" => 1, "ncode" => "N1234AA", "pt" => 2}], [{"allcount" => 0}])
    row = described_class.fetch(date: "2026-10-27", kind: "d").first
    expect(row).to include("ncode" => "n1234aa", "title" => nil, "rank" => 1)
  end
end
