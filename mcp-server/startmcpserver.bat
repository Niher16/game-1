@echo off
REM Batch file to properly start MCP Server with correct project path
REM Place this in your mcp-server directory and run it

echo Starting Godot MCP Server for Thane's Project...
echo Project Path: D:\GAME PROJECT\Game\game

REM Set the environment variable to the correct project path
set GODOT_PROJECT_PATH=D:\GAME PROJECT\Game\game

REM Change to the MCP server directory (adjust if needed)
cd /d "%~dp0"

REM Start the MCP server
echo MCP Server starting...
node godot-mcp-server.js

REM Keep window open if there's an error
if errorlevel 1 (
    echo.
    echo Error starting MCP server!
    pause
)

REM Alternative PowerShell version (save as start_mcp_server.ps1)
REM # PowerShell version
REM $env:GODOT_PROJECT_PATH = "D:\GAME PROJECT\Game\game"
REM Write-Host "Starting Godot MCP Server..."
REM Write-Host "Project Path: $env:GODOT_PROJECT_PATH"
REM Set-Location $PSScriptRoot
REM node godot-mcp-server.js