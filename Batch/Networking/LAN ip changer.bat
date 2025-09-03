@echo off
setlocal enabledelayedexpansion

:: Name of your network adapter
set adapter=Ethernet

:: Generate a random number between 50 and 250
set /a rand=%random%*200/32768+50

:: Build the new IP
set newip=10.0.0.!rand!

echo Changing IP address of %adapter% to %newip% ...

netsh interface ip set address name="%adapter%" static %newip% 255.255.255.0 10.0.0.1
netsh interface ip set dns name="%adapter%" static 8.8.8.8
netsh interface ip add dns name="%adapter%" 8.8.4.4 index=2

echo Done. New IP is %newip%
pause
