# blessing-skin-docker
Dockerfile for Blessing Skin Server

## Features

### /setup Protection
By default, `/setup` is protected by a randomly generated password. The password is printed to the console at startup. You must enter the password to access the install wizard.

You can disable this feature by adding `--disable-setup-password` option to the `docker run` command.
