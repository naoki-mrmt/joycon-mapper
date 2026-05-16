cask "joycon-mapper" do
  version "0.8.0"
  sha256 "657e417ecb7f9f1c54148c7b51dbee65ba4094c78fab433ba240ff7944556d97"

  url "https://github.com/naoki-mrmt/joycon-mapper/releases/download/v#{version}/JoyconMapper-v#{version}.zip"
  name "Joycon Mapper"
  desc "Use a Nintendo Switch Joy-Con (L) as a pointer and shortcut controller"
  homepage "https://github.com/naoki-mrmt/joycon-mapper"

  depends_on macos: ">= :tahoe"

  app "JoyconMapper.app"

  zap trash: "~/Library/Preferences/com.muramoto-co.JoyconMapper.plist"
end
