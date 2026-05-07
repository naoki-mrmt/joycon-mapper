cask "joycon-mapper" do
  version "0.1.0"
  sha256 "742fae045014fb26077901eefd73ded9d0752f0b7a303c5c1d2f9eff8dd894fc"

  url "https://github.com/naoki-mrmt/joycon-mapper/releases/download/v#{version}/JoyconMapper-v#{version}.zip"
  name "Joycon Mapper"
  desc "Use a Nintendo Switch Joy-Con (L) as a macOS pointer and shortcut controller"
  homepage "https://github.com/naoki-mrmt/joycon-mapper"

  app "JoyconMapper.app"

  zap trash: [
    "~/Library/Preferences/com.muramoto-co.JoyconMapper.plist",
  ]
end
