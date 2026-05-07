cask "joycon-mapper" do
  version "0.1.0"
  sha256 "<replace-with-release-sha256>"

  url "https://github.com/naoki-mrmt/joycon-mapper/releases/download/v#{version}/JoyconMapper-v#{version}.zip"
  name "Joycon Mapper"
  desc "Use a Nintendo Switch Joy-Con (L) as a macOS pointer and shortcut controller"
  homepage "https://github.com/naoki-mrmt/joycon-mapper"

  app "JoyconMapper.app"

  zap trash: [
    "~/Library/Preferences/com.muramoto-co.JoyconMapper.plist",
  ]
end
