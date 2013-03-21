sdb
===

SDB is a simple block-based Cocoa / Objective-C client that helps you make requests to Amazon Web Services SimpleDB.

sdb supports these methods:

CreateDomain
DeleteDomain
DomainMetadata
ListDomains
GetAttributes
Select
PutAttributes

Status
======

SDB is largely untested and shouldn't be relied on for production quality projects. It requires XCode 4.2 for ARC support. It's been tested only lightly on iOS. ChangeSet support is untested.

Todo
====

- Documentation
- Complete error reporting
- Error retry falloff logic
- Full iOS support
- Unit Tests
- Test ChangeSets