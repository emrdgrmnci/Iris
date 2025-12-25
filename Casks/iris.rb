cask "iris" do
  version "0.1.1"
  sha256 "d1c2f4ee5cf16bbaa7d4aade84ad2b2c7da44b4480ca82367a9352dd27673f96"

  url "https://github.com/ahmetb/Iris/releases/download/v#{version}/Iris-v#{version}.zip"
  name "Iris"
  desc "Floating webcam viewing window (a hand mirror)"
  homepage "https://github.com/ahmetb/Iris"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Iris.app"

  zap trash: [
    "~/Library/Preferences/com.iris.app.plist",
  ]
end
