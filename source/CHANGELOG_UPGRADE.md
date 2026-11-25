# SHOPMASTER PRO upgrade notes

## Version 0.3.0+3

- Added a three-dot action menu to each sales and purchase history row.
- The history menu opens the existing edit form for the selected document.
- The history menu can delete the selected document after an explicit confirmation.
- Delete uses the existing repository transaction, which reverses stock, serial,
  party-balance and cash/bank effects where the repository rules permit it.
- Existing document-detail Edit and Delete actions remain available.
- The sales and purchase screens share the same history implementation, so both
  document types receive the actions.

## Validation limitations

- Flutter and Dart SDKs were not available in this workspace.
- The project was not compiled, run on a device, or tested against a live database.
- Cloud sync, OAuth Gmail sending, automatic WhatsApp sending, login/roles,
  audit logs and a native Windows database implementation still require separate
  service setup and development; they are not included by this change.
