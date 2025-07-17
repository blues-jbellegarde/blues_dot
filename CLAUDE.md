# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository named "blues_dot" designed to centralize and manage personal configuration files using GNU Stow for symlink management.

## Goals

The primary goal of this repository is to:
1. Move dotfiles from the home directory (`~`) and config folder (`~/.config`) into this centralized repository
2. Use GNU Stow to create symlinks from this repository back to the appropriate locations in the home directory and config folder
3. Provide version control and backup for personal configuration files
4. Enable easy deployment of dotfiles across multiple machines

Current status: Basic setup files only (MIT License, README.md)

## Repository Structure

This is a fresh dotfiles repository with no actual configuration files or scripts yet. The repository is structured as a standard dotfiles project but is currently empty of actual dotfiles content.

## Development Context

This appears to be a newly initialized dotfiles repository that is ready to be populated with personal configuration files, shell scripts, and system setup automation typically found in dotfiles projects.

## Key Points for Future Development

- This is a personal dotfiles repository following standard dotfiles conventions with GNU Stow for symlink management
- Files should be organized in packages (subdirectories) that mirror the target directory structure
- Use `stow <package-name>` to create symlinks from the repository to the home directory
- Use `stow -D <package-name>` to remove symlinks
- No build tools, test frameworks, or package managers are currently configured
- Standard git workflow applies for version control

## Common Commands

- `stow <package>` - Create symlinks for a package
- `stow -D <package>` - Remove symlinks for a package  
- `stow -R <package>` - Restow (remove then recreate) symlinks for a package

## Documentation

- GNU Stow documentation: https://www.gnu.org/software/stow/manual/stow.html