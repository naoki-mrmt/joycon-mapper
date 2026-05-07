cask "joycon-mapper" do
  version "0.2.0"
  sha256 "c559f6a7b5a14dfa9a7e150377aa9debfd8ed6464929ed71ad73c833c246d747"

  url "https://github.com/naoki-mrmt/joycon-mapper/releases/download/v#{version}/JoyconMapper-v#{version}.zip"
  name "Joycon Mapper"
  desc "Use a Nintendo Switch Joy-Con (L) as a pointer and shortcut controller"
  homepage "https://github.com/naoki-mrmt/joycon-mapper"

  depends_on macos: ">= :tahoe"

  app "JoyconMapper.app"

  zap trash: "~/Library/Preferences/com.muramoto-co.JoyconMapper.plist"
end
