## Windows cloud sync service.

Simplify making a all-in-one local file system to cloud object storage synchronization service.

This is similar to 

This is an alternative to having a google drive mounted locally, dropbox or similar.
It is meant to be as simple and fail-proof as possible, and to run in a server environment.

### Components

- [rclone](https://rclone.org/) is a system for synchronizing local and remote files.
- [nssm](https://nssm.cc/), the Non-Sucking Service Manager is a simple service manager for Windows

### Usage

This assumes you are running on Linux

#### Installation

1. Clone this repo
2. Run rclone config to create a new default config.
3. R
3. Run build.sh
4. Move the win-cloud-sync.zip file to the server and unzip it.
5. Run `install.cmd` on the server to install the service using nssm.

#### Removal

1. Run `uninstall.cmd` on the server to uninstall the service.
2. Remove the installation directory.

