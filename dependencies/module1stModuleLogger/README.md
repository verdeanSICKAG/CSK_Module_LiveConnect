# CSK_1stModule_Logger

Module to provide logger functionality to log messages of all modules.  

![](https://github.com/SICKAppSpaceCodingStarterKit/CSK_1stModule_Logger/blob/main/docu/media/UI_Screenshot.png)

## How to Run

The app provides Logger functionality inclusive a intuitive GUI to see and download the Log.  
If it should keep all logs (incl. in global scope) it should be first app in alphabetic order.  
INFO: If you want to use 'logHandler:addFileSink' you should use it on a SD card file instead of device internal path, to reduce write accesses on the device internal flash storage.  

For further information check out the [documentation](https://raw.githack.com/SICKAppSpaceCodingStarterKit/CSK_1stModule_Logger/main/docu/CSK_1stModule_Logger.html) in the folder "docu".

## Information

Tested on  

1. SIM1012        - Firmware 2.2.0
2. SICK AppEngine - Firmware 1.3.2

This module is part of the SICK AppSpace Coding Starter Kit developing approach.  
It is programmed in an object oriented way. Some of these modules use kind of "classes" in Lua to make it possible to reuse code / classes in other projects.  
In general it is not neccessary to code this way, but the architecture of this app can serve as a sample to be used especially for bigger projects and to make it easier to share code.  
Please check the [documentation](https://github.com/SICKAppSpaceCodingStarterKit/.github/blob/main/docu/SICKAppSpaceCodingStarterKit_Documentation.md) of CSK for further information.  

## Topics

Coding Starter Kit, CSK, Module, SICK-AppSpace, Log, Logger
