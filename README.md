# AutoKali (Menu-Driven Version)

## Overview
AutoKali is a menu-driven installer and management tool for configuring Kali Linux systems for penetration testing labs.

## Features
- Menu-driven interface
- Git repository management
- Safe updates and force reset options
- Modular structure

## Usage
```bash
chmod +x AutoKali.sh
./AutoKali.sh
```

## Menu Options
1. Update all repositories
2. Update /opt repositories
3. Update shared repositories
4. Force update (destructive)
5. Exit

## Notes
- Force update will remove local changes
- Shared directory must exist at /media/sf_X_DRIVE

## Author
Terence Martin
