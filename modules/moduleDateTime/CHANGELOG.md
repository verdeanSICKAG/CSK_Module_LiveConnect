# Changelog
All notable changes to this project will be documented in this file.

## Release 3.0.0

### Improvements
- Renamed "Ntp" to "NTP" within functions/events
- Using recursive helper functions to convert Container <-> Lua table

## Release 2.6.0

### Improvements
- Update to EmmyLua annotations
- Usage of lua diagnostics
- Documentation updates

## Release 2.5.0

### Improvements
- Using internal moduleName variable to be usable in merged apps instead of _APPNAME, as this did not work with PersistentData module 

## Release 2.4.1

### Improvements
- Naming of UI elements and adding some mouse over info texts
- Appname added to log messages
- Added ENUM
- Minor edits

### Bugfix
- UI events notified after pageLoad after 300ms instead of 100ms to not miss


## Release 2.4.0

### Improvements
- Check if running on Emulator / SAE -> time settings deactivated
- Update of helper funcs to support 4-dim tables for PersistentData
- Minor code edits / docu updates

### Bugfix
- UI reload was too early after first logger setup for UserManagement feature

## Release 2.3.1

### Bugfix
- UI files were not updated

## Release 2.3.0

### New features
- NTPClient functionality
- Setting of timezone
- Showing UTC and Local time in UI

### Improvements
- Loading only required APIs ('LuaLoadAllEngineAPI = false') -> less time for GC needed
- ParameterName available on UI
- Manual times not stored as parameters anymore
- Updated documentation

## Release 2.2.0

### Improvements
- Prepared for all CSK user levels: Operator, Maintenance, Service, Admin
- Renamed page folder accordingly to module name
- Updated documentation

### Bugfix
- Changed status type of user levels from string to bool

## Release 2.1.0

### New features
- Added support for userlevels, required userlevel for the whole UI is Maintenance

## Release 2.0.0

### New features
- Update handling of persistent data according to CSK_PersistentData module ver. 2.0.0

## Release 1.0.0
- Initial commit