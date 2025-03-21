# ScriptingPortfolio
Some curated samples of my work in PowerShell (and Bash)
 
## Introductory Notes  
Welcome to my portfolio! I am an Infrastructure Engineer looking to showcase some of the work that I've done. I wanted to go beyond saying "10 years of PowerShell experience" on my resume (2025). I wanted to demonstrate how I used my automation skills over the years. 

## Redaction Notes  
I reproduced scripts that are similar to scripts that ran in actual production environments. In order to exclude sentitive information, I generalized some segments, or marked them as "redacted". So for example, you may see a string in the format "C:\Sample\file.csv". If the string (folder path in this case) was changed to correctly represent something in the environment, the script would run correctly. You may also see \[REDACTED\] in other cases. 

## Specific Folder Notes
### `ConnectPartner`
Custom script written to ease the process of connecting to Linux KVM host servers at our Partner datacenters. The list of servers come as a .csv file, which was datadumped regularly.

### `InstallSplunk`
Install Splunk log monitoring agent and add customizations (modified config files, registry). You are welcome to download and use `Find-SplunkVersion.ps1` and modify it to find the version string for any software. You need to merely change the `$SearchString` and the file name. The `.json` file contains specific customizations that I can modify without changing any scripts. 

### `RestIPFilters`
We hosted custom SaaS for customers (conveniently labled "Custom Software"). I was asked to create a set of scripts to read, add, remove, and change IPs in the IP filters used by this software. The requirement was to access the IP filters using the REST API. I actually produced a full module that technicians can use to make new scripts, or interact with the cmdlets directly. Other scripts are a front end for the module for technicians who aren't versed in PowerShell or just want to make basic changes. The `.json` file contains specific customizations that I can modify without changing any scripts. 

### `ZZ-Archive`
Older files, which may not represent my current style, but are still worth including.
