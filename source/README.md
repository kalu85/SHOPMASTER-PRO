# SHOPMASTER PRO

Billing, inventory, accounting and GST management for Android (Flutter, offline-first, INR).

## Status: Phases 1-10 written. Build checked only by GitHub Actions.

Nothing below has been tested on a phone by the developer. "Written" means the code
exists and passed the checks listed under "How it was checked". Please test each item
on your phone and report problems.

### Written (Phases 1-4, earlier)
- 15-module navigation, navy/cyan theme, department colours, dashboard
- Items & Stock, Party Details (customers and suppliers)
- Sales and purchase invoices, quotations, returns, GST / NON-GST, CGST+SGST / IGST
- Stock, party balance and payment updates, automatic numbering

### Written (edit / delete, newest)
- **Edit** and **Delete** on every saved sale, purchase, quotation and return (available
  from both the document detail screen and the three-dot menu on the history list). The number stays the same on edit. Stock, serial
  numbers, party balance and cash/bank balance are undone and re-applied in one step;
  if anything fails nothing changes. Deleted numbers are never reused.
- Limits: a purchase cannot be edited/deleted once one of its serial numbers has been
  sold; returns that carry serial numbers cannot be edited/deleted. In edit mode the
  "stock will go negative" warning counts stock after the original sale.
- Checked only by a SQLite simulation of the logic; not run on a phone.
- Items have an optional Supplier name (database version 4).

### Written (Phases 5-10)
- **PDF invoices** (A4 and 80mm receipt): logo upper-left; shop name, address, phone
  and (GST only) GSTIN upper-right; TAX INVOICE (GST) or SALES INVOICE (NON-GST);
  item table in the exact order No. | Item | HSN | Serial No. | Warranty | Qty | Rate |
  Tax | Discount | Amount; Tax column and GST summary hidden for NON-GST;
  Subtotal, Discount, Grand total, Received, Due; bank, UPI and UPI QR;
  "Authorised Shop Signature" and footer; no customer signature;
  warranty start/expiry dates are never printed (the duration only).
- Print, Share PDF, WhatsApp chat link and Email from the invoice screen
- **Shop Settings**: shop details, logo, GSTIN, bank, UPI, invoice prefix, footer, defaults
- **Serial Tracking** and **Warranty**: serials typed on purchase/sale lines, unique,
  sold/in-stock/returned status, warranty start/expiry kept internally, Active /
  Expiring (30 days) / Expired lists, warranty claims
- **Cash & Bank**: cash drawer and bank accounts with live balances, deposit,
  withdraw, transfer, manual money in/out, history. Invoices and payments post here.
- **Expenses**: categories, paid-by, posts to the chosen account
- **Party ledger**: invoices, returns, payments received/made, running balance,
  statement PDF, WhatsApp payment reminder
- **Reports** (14): sales/purchases daily-monthly-yearly, GST, NON-GST, profit & loss,
  stock, low stock, customer/supplier outstanding, cash, bank, expenses, warranty,
  serials. Export to PDF and spreadsheet (CSV, opens in Excel/Sheets).
- **Global Search**: items, customers, suppliers, sales, purchases, serial numbers,
  warranty, payments; category chips and a date range
- **Backup & Restore**: manual backup, automatic daily backup (latest 10 kept),
  restore with confirmation (a safety copy is made first), share a backup file out,
  restore from a file
- **WhatsApp Connect**: payment reminders and free messages. WhatsApp opens with the
  text typed in; you press send.
- **Gmail Integration**: payment reminders open your mail app; PDFs are emailed
  through Share PDF. See "Not built".

## NOT built (do not assume these work)
- **Firebase / cloud sync / cloud backup**: needs your own Firebase project and
  google-services.json. Not included. Backups are on the phone only (share them out
  to Google Drive manually).
- **Gmail sign-in (OAuth) and sending from your Gmail account**: needs your own Google
  Cloud OAuth client. Not included. Email goes through the phone's mail app.
- **WhatsApp automatic sending** (official Business API): not included.
- **Login, user roles, audit logs**: not included.
- **Audit history** of edits (who changed what): not included.
- **Windows app**: sqflite is Android-only; Windows needs more work.
- **.xlsx files**: reports export CSV (opens in Excel) and PDF.
- Cost of goods in profit & loss uses each item's current purchase rate (an estimate).

## How it was checked (no Flutter on the build machine)
- Bracket balance and import-path check of Dart files (a rough script; not the Dart compiler)
- SQLite: the fresh-install schema and the upgrade-from-earlier-version schema produce
  the same tables (checked in Python). Earlier-phase invoice/stock/party flows were
  simulated in SQLite. The Phase 5-10 queries (reports, search, ledger, cash/bank,
  serials) were NOT run against sample data; expect to find bugs there.
- GST math and serial/warranty date rules have Dart unit tests (run only on GitHub)
- Compilation and the Dart tests (`flutter analyze`, `flutter test`) run only on GitHub

## Build
GitHub Actions workflow `.github/workflows/build-apk.yml` generates the Android
folder, builds `app-release.apk` and uploads it as artifact `shopmaster-pro-apk`.

Requires Flutter 3.27 or newer.

## Folder structure
    lib/core/{db,models,data,services,utils,widgets,theme}
    lib/features/{shell,dashboard,stock,parties,invoices,serial,warranty,cashbank,
                  expenses,reports,search,backup,connect,settings}
    test/


## Consolidated update notes

This consolidated source bundle includes:
- Product picker columns for ITEM, SALE PRICE, PURCHASE PRICE, and STOCK.
- Sales and purchase invoice edit/delete actions from the invoice list.
- Invoice Terms & Conditions in both A4 and 80mm thermal PDF layouts:
  - E.& O.E.
  - Goods once sold will not be taken back.
  - Burnt, tampered-serial-number, and broken items are not covered by warranty; show the bill copy at warranty time.
  - Manufacturer warranties follow the manufacturer's standard warranty terms.
- Existing GST/non-GST invoice generation and project assets.

## Verification status

The ZIP structure and source contents were inspected. Flutter analyze, automated tests,
Android APK compilation, and physical-device printing still need to be run in a Flutter
environment. Back up business data before testing edit/delete and stock adjustments.
