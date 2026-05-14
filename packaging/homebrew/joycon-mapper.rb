cask "joycon-mapper" do
  version "0.5.0"
  sha256 "a1286db36c68af0a4eaaf52147a07f54068b0e7cd1dde2735434bd4591a43f13"

  url "https://github.com/naoki-mrmt/joycon-mapper/releases/download/v#{version}/JoyconMapper-v#{version}.zip"
  name "Joycon Mapper"
  desc "Use a Nintendo Switch Joy-Con (L) as a pointer and shortcut controller"
  homepage "https://github.com/naoki-mrmt/joycon-mapper"

  depends_on macos: ">= :tahoe"

  app "JoyconMapper.app"

  zap trash: "~/Library/Preferences/com.muramoto-co.JoyconMapper.plist"
end
