# AOI Process

## The Context
We had a manufacturing line that made circuit boards at a high volume. On the line were machines that did Automated Optical Inspection (AOI). The AOI system validated the circuit boards as they went through, then saved the images in a proprietary format that was based on bitmap. The Engineers responsible for this system wanted to retain the saved images for an indefinite period of time, so they can review images of any board.

## The Problem
The saved images were very large files. When the line was at full production, I estimated that we would have to save 2 Terabytes of images per week. Our available network storage was 10 TB. We did our best by offloading the images to tape backup, but even as the line was running at 25% volume, any failures led to images being lost or storage filling up. Oh, and by the way, this was hurting performance across the network due to network usage and server storage overutilization. 

## The Solution
I started by working with the engineers and the third party vendor who supports the AOI system. The vendor did not have a specific solution for our use case. However, they did provide a command line utility that would extract individual image files and convert them to JPG format. The engineers really only needed to retain an few images and no metadata for future review. Given this information, I found that we could reduce the amount of data saved per board by 90%. 

I designed a PowerShell script (`LocalProc-VITArchive.ps1`) to run on each AOI computer that extracted the images we needed and saved them in a folder structure on our file server. The server backed up the images to an external drive and to tape backup. I implemented a 6 month rotation on the file server. Given that backups did not fail, a PowerShell script (`Procedure-AOIPostArchive.ps1`) was scheduled to run that purged image files every night. 

In order to support this configuration and maintain performance, we added a 50TB SAN, upgraded our tape drive to LTO6, and added solid state drives to the AOI computers. 

## Additional Info
* `\scripts\` ~ Several scripts shared the same code base. Splitting off portions of code into individual scripts allowed for code recycling and (usually) simplified updates
* `Procedure-ArchiveOmronAOI.ps1` ~ Another image conversion and cleanup script, which was for another AOI system. Scheduled nightly and used built in .Net code to convert from `.BMP` to `.JPG`
* `Tool-TransferVITAOI.ps1` ~ While the process above was being built out, images still had to be generated and saved somewhere. This script allowed me to go through an old folder structure and _incorporate_ previous images into a more consistent folder structure, on an adhoc basis. 
