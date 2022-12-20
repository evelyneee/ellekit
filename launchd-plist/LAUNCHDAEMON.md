# Why does this exist?
When you start up your Mac, in order to use ElleKit, you need to manually run the loader script. This is a tedious thing to have to do on every startup, and it's also easily avoidable.

# What can we do about it?
We can use a LaunchDaemon that automatically loads ElleKit on startup for a seamless experience. As soon as you log in to your user account on your Mac, ElleKit is already injected.

# How can I install it?
1. Download [this plist](./com.evln.ellekit.startup.plist?raw=1) and save it to `/Library/LaunchDaemons/com.evln.ellekit.startup.plist` (requires root)
2. Open up a terminal and run `sudo launchctl load -w /Library/LaunchDaemons/com.evln.ellekit.startup.plist`
3. Reboot your Mac, and ElleKit should be injected on startup
