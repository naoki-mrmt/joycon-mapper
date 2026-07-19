cask "joycon-mapper" do
  version "0.11.0"
  sha256 "62118491dfb246d2da037534de7cdf680efb21e13938bc649d7bae1c8a3e6e06"

  url "https://github.com/naoki-mrmt/joycon-mapper/releases/download/v#{version}/JoyconMapper-v#{version}.zip"
  name "Joycon Mapper"
  desc "Use a Nintendo Switch Joy-Con (L) as a pointer and shortcut controller"
  homepage "https://github.com/naoki-mrmt/joycon-mapper"

  depends_on macos: :tahoe

  app "JoyconMapper.app"

  zap trash: "~/Library/Preferences/com.muramoto-co.JoyconMapper.plist"
end
