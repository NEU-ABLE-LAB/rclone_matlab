# rclone Matlab wrapper
This Matlab class serves as a wrapper to the command line tool [Rclone](https://rclone.org/). Rclone is a command line program to sync files and directories to and from local storage and cloud storage.

Rclone and this wrapper are particularly useful in Matlab for working with large datasets of files stored or backed-up in the cloud.

## Installation
Rclone must be present on your system path. 

 - To install rclone on Windows systems, the [Chocolatey](https://chocolatey.org/) package manager is recommend. Install Chocolately, then run `choco install rclone`
 - To install rclone on Linux/macOS/BSD systems, run `curl https://rclone.org/install.sh | sudo bash`

After installation, check that rclone was successfully added to the system path by opening the command line and typing `rclone --help`. If you aren't prompted with the rclone help document, then you will have to manually add rclone to your system path. ([Windows](https://www.howtogeek.com/118594/how-to-edit-your-system-path-for-easy-command-line-access/), [Linux](https://www.computerhope.com/issues/ch001647.htm) )
 
Before using the Matlab wrapper, you must [configure rclone](https://rclone.org/docs/) to access your remote storage.
 
You can import this git repo as a [submodule](https://blog.github.com/2016-02-01-working-with-submodules/) into your project, just be sure to name the folder `@rclone` so that [Matlab knows that there is a class in the folder](https://www.mathworks.com/help/matlab/matlab_oop/organizing-classes-in-folders.html). 
 
## Usage

The basic usage of rclone to download a directory of data from the cloud is as follows:

```matlab
[status,cmdout] = rclone('copy %s %s','remote:path-to/data','local/path/to-data/');
```

This returns the rclone `status` int (0 for success) and `cmdout` the text that would have been written to the command line.

There are additional special outputs for the `[copy](https://rclone.org/commands/rclone_copy/)`, `[md5sum](https://rclone.org/commands/rclone_md5sum/)`, and `[lsjson](https://rclone.org/commands/rclone_lsjson/)` commands

See `rclone.m` for details or type `doc rclone` in Matlab.