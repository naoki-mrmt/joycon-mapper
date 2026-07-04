cask "joycon-mapper" do
  version "0.10.0"
  sha256 "5eb8b596cce6fe17a6e1d958cdef98f561fb266daaa6d6ee6bdd81d5f682673c"

  url "https://github.com/naoki-mrmt/joycon-mapper/releases/download/v#{version}/JoyconMapper-v#{version}.zip"
  name "Joycon Mapper"
  desc "Use a Nintendo Switch Joy-Con (L) as a pointer and shortcut controller"
  homepage "https://github.com/naoki-mrmt/joycon-mapper"

  depends_on macos: ">= :tahoe"

  app "JoyconMapper.app"

  zap trash: "~/Library/Preferences/com.muramoto-co.JoyconMapper.plist"
end
