# Chia Plotting Optimization Script
This script optimizes the movement of Chia Bladebit Cuda plots from SSDs to HDDS. The HDDs write speed is usually the bottleneck of GPU plotting. The script try to prevent GPUT plotting on a SSD which is transferring completed plot to HDD.

## Overview

1. The script determines which SSD is available.
2. It then triggers the `Bladebit` tool on the available SSD.
3. Upon plot completion on an SSD, the script transfers it to an HDD using a round-robin approach.

## Flow:

1. For each SSD:
   - If SSD is free (neither plotting nor transferring), start `Bladebit`.
   - If an SSD has a finished plot and isn't in the midst of a transfer, initiate the copy to the next HDD in the sequence.

2. Pause briefly and repeat the process.

The script employs a flagging system to signify when an SSD is being read for copying, ensuring optimal SSD bandwidth usage.

## How to use:

1. Call the script with the desired number of plots followed by your SSD paths, a `--` separator, and your HDD paths.
   - Example: `./PlotPipelineManager.sh 1000 /path/to/SSD1 /path/to/SSD2 -- /path/to/HDD1 /path/to/HDD2`
2. Monitor the progress.

Always trial the script in a controlled environment before a production deployment.
