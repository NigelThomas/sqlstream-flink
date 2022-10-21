# The assets directory

If there are any SQLstream installers in this directory, then `runSetup.sh` can find them and install them.

The order of search will be:
1. Check in the `assets` directory
2. Check in `/tmp` 
3. Check at http://downloads.sqlstream.com

Any SQLstream installer downloaded by `runSetup.sh` will be saved in `/tmp`. Move it into the `assets` directory if you want to retain it across system shutdowns.
