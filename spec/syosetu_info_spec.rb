# frozen_string_literal: true

require "forwardable"
require_relative "../lib/narou"
$stdout2 ||= $stdout
require_relative "../lib/sitesetting"

# Regression coverage for upstream issues #445 / #450 and PR #446.
describe "小説家になろうの作品情報" do
  %w(ncode.syosetu.com novel18.syosetu.com).each do |domain|
    context domain do
      let(:setting) { SiteSetting.load_file(File.expand_path("../webnovel/#{domain}.yaml", __dir__)) }
      let(:source) { File.read(File.expand_path("data/syosetu/infotop.html", __dir__), encoding: "UTF-8") }

      def parse(setting, source)
        setting.multi_match(Helper.pretreatment_source(source.dup), *%w(t nt ga s gf nu gl w l sitename))
        setting
      end

      ["pretty", "compact", "indented", "CRLF"].each do |format|
        it "#{format} HTMLから作品情報を取得できる" do
          html = case format
                 when "compact" then source.gsub(/>\s+</, "><")
                 when "indented" then source.gsub("\n", "\n  ")
                 when "CRLF" then source.gsub("\n", "\r\n")
                 else source
                 end
          result = parse(setting, html)
          expect(result["title"]).to eq "動作確認の物語"
          expect(result["novel_type"]).to eq "連載中"
          expect(result["general_all_no"]).to eq "123"
          expect(result["story"]).to match(/\A一行目。<br \/>\s*二行目。\z/)
          expect(result["general_firstup"]).to eq "2024年01月02日 03時04分"
          expect(result["novelupdated_at"]).to eq "2026年10月29日 12時00分"
          expect(result["general_lastup"]).to eq "2026年10月29日 12時00分"
          expect(result["writer"]).to eq "確認用著者"
          expect(result["length"]).to eq "123,456"
          expect(result["sitename"]).to eq(domain == "ncode.syosetu.com" ? "小説家になろう" : "ノクターンノベルズ")
        end
      end

      it "リンクがない作者名を取得できる" do
        html = source.sub('<a href="https://mypage.syosetu.com/123/">確認用著者</a>', "確認用著者")
        expect(parse(setting, html)["writer"]).to eq "確認用著者"
      end

      it "完結済・短編の種別を取得できる" do
        %w(完結済 短編).each do |status|
          expect(parse(setting, source.sub("連載中", status))["novel_type"]).to eq status
        end
      end

      it "最終掲載日・最終更新日の表記を取得できる" do
        %w(最終掲載日 最終更新日).each do |label|
          expect(parse(setting, source.sub("最新掲載日", label))["novelupdated_at"]).to eq "2026年10月29日 12時00分"
        end
      end

      it "サイト定義バージョンを更新して旧定義の上書きを防ぐ" do
        expect(setting["version"]).to eq 2.2
      end
    end
  end
end
