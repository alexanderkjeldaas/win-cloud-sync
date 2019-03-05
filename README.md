## Windows cloud sync service.

Simplify making a all-in-one local file system to cloud object storage synchronization service.

This is an alternative to having a google drive mounted locally, dropbox or similar.
It is meant to be as simple and fail-proof as possible, and to run in a server environment.

### Components

- [rclone](https://rclone.org/) is a system for synchronizing local and remote files.
- [nssm](https://nssm.cc/), the Non-Sucking Service Manager is a simple service manager for Windows

### Usage

This assumes you are running on Windows Server 2012 R2

```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
```

Then save the [`win-cloud-sync.ps1`](https://raw.githubusercontent.com/alexanderkjeldaas/win-cloud-sync/master/win-cloud-sync.ps1) file 
to local disk and run it (`.\win-cloud-sync.ps1`) from within a shell window.

