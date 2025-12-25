cask "iris" do
  version "0.1.2"
  sha256 "8d1c6fd7276dba96e2f1337d3c5bddc99c360a9055f06d8613a5d8044afb53a2"

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
