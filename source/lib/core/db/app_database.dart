import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database (offline-first).
///
/// Version history:
///   1 - products, parties, stock_movements
///   2 - invoices, invoice_items, counters
///   3 - settings, accounts, account_txns, expenses, party_payments,
///       serials, warranty_claims; serial/warranty columns on invoice_items;
///       account_id on invoices
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String fileName = 'shopmaster.db';

  Database? _db;

  Future<String> get path async =>
      p.join(await getDatabasesPath(), fileName);

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await openDatabase(
      await path,
      version: 5,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, version) async {
        await _createV1(d);
        await _createV2(d);
        await _createV3(d);
        await _upgradeToV4(d);
        await _upgradeToV5(d);
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(d);
        if (oldVersion < 3) await _upgradeToV3(d);
        if (oldVersion < 4) await _upgradeToV4(d);
        if (oldVersion < 5) await _upgradeToV5(d);
      },
    );
    _db = opened;
    return opened;
  }

  /// Closes the connection (used before restoring a backup file).
  Future<void> close() async {
    final d = _db;
    _db = null;
    if (d != null) await d.close();
  }

  Future<void> _createV1(Database d) async {
    await d.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        hsn TEXT NOT NULL DEFAULT '',
        barcode TEXT UNIQUE,
        purchase_rate REAL NOT NULL DEFAULT 0,
        sale_rate REAL NOT NULL DEFAULT 0,
        gst_rate INTEGER NOT NULL DEFAULT 0,
        opening_stock REAL NOT NULL DEFAULT 0,
        current_stock REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        is_service INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await d.execute('CREATE INDEX idx_products_name ON products(name)');

    await d.execute('''
      CREATE TABLE parties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK (type IN ('customer', 'supplier')),
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        gstin TEXT NOT NULL DEFAULT '',
        opening_balance REAL NOT NULL DEFAULT 0,
        current_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await d.execute('CREATE INDEX idx_parties_type_name ON parties(type, name)');

    await d.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        qty_change REAL NOT NULL,
        reason TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await d.execute(
        'CREATE INDEX idx_movements_product ON stock_movements(product_id)');
  }

  Future<void> _createV2(Database d) async {
    await d.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL CHECK (kind IN ('sale', 'purchase')),
        doc_type TEXT NOT NULL CHECK (doc_type IN ('invoice', 'quotation', 'return')),
        number TEXT NOT NULL,
        party_id INTEGER REFERENCES parties(id) ON DELETE SET NULL,
        party_name TEXT NOT NULL DEFAULT '',
        party_phone TEXT NOT NULL DEFAULT '',
        party_address TEXT NOT NULL DEFAULT '',
        party_gstin TEXT NOT NULL DEFAULT '',
        is_gst INTEGER NOT NULL DEFAULT 0,
        is_interstate INTEGER NOT NULL DEFAULT 0,
        invoice_date TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount_total REAL NOT NULL DEFAULT 0,
        taxable_total REAL NOT NULL DEFAULT 0,
        cgst REAL NOT NULL DEFAULT 0,
        sgst REAL NOT NULL DEFAULT 0,
        igst REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        paid REAL NOT NULL DEFAULT 0,
        due REAL NOT NULL DEFAULT 0,
        pay_mode TEXT NOT NULL DEFAULT 'Cash',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        UNIQUE (kind, doc_type, number)
      )
    ''');
    await d.execute(
        'CREATE INDEX idx_invoices_kind_date ON invoices(kind, invoice_date)');

    await d.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        hsn TEXT NOT NULL DEFAULT '',
        qty REAL NOT NULL,
        rate REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        gst_rate INTEGER NOT NULL DEFAULT 0,
        taxable REAL NOT NULL DEFAULT 0,
        cgst REAL NOT NULL DEFAULT 0,
        sgst REAL NOT NULL DEFAULT 0,
        igst REAL NOT NULL DEFAULT 0,
        amount REAL NOT NULL DEFAULT 0
      )
    ''');
    await d.execute(
        'CREATE INDEX idx_items_invoice ON invoice_items(invoice_id)');

    // Running invoice numbers. Never reused, even if invoices are removed.
    await d.execute('''
      CREATE TABLE counters (
        key TEXT PRIMARY KEY,
        value INTEGER NOT NULL
      )
    ''');
  }

  /// v5: preserve each item's purchase cost at the time of sale.
  Future<void> _upgradeToV5(Database d) async {
    await d.execute('ALTER TABLE invoice_items ADD COLUMN purchase_rate_snapshot REAL NOT NULL DEFAULT 0');
  }

  /// v4: the usual supplier of an item.
  Future<void> _upgradeToV4(Database d) async {
    await d.execute(
        'ALTER TABLE products ADD COLUMN supplier_id INTEGER REFERENCES parties(id) ON DELETE SET NULL');
    await d.execute(
        "ALTER TABLE products ADD COLUMN supplier_name TEXT NOT NULL DEFAULT ''");
  }

  /// Existing v2 databases: add columns, then the new tables.
  Future<void> _upgradeToV3(Database d) async {
    await d.execute(
        "ALTER TABLE invoice_items ADD COLUMN serials TEXT NOT NULL DEFAULT ''");
    await d.execute(
        'ALTER TABLE invoice_items ADD COLUMN warranty_months INTEGER NOT NULL DEFAULT 0');
    await d.execute('ALTER TABLE invoices ADD COLUMN account_id INTEGER');
    await _createV3Tables(d);
  }

  /// Fresh installs: the v2 tables above lack the v3 columns, so add them too.
  Future<void> _createV3(Database d) async {
    await d.execute(
        "ALTER TABLE invoice_items ADD COLUMN serials TEXT NOT NULL DEFAULT ''");
    await d.execute(
        'ALTER TABLE invoice_items ADD COLUMN warranty_months INTEGER NOT NULL DEFAULT 0');
    await d.execute('ALTER TABLE invoices ADD COLUMN account_id INTEGER');
    await _createV3Tables(d);
  }

  Future<void> _createV3Tables(Database d) async {
    await d.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await d.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL CHECK (kind IN ('cash', 'bank')),
        name TEXT NOT NULL,
        bank_name TEXT NOT NULL DEFAULT '',
        account_no TEXT NOT NULL DEFAULT '',
        ifsc TEXT NOT NULL DEFAULT '',
        upi_id TEXT NOT NULL DEFAULT '',
        opening_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await d.execute('''
      CREATE TABLE account_txns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        direction TEXT NOT NULL CHECK (direction IN ('in', 'out')),
        amount REAL NOT NULL,
        kind TEXT NOT NULL,
        ref TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        txn_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await d.execute(
        'CREATE INDEX idx_txns_account_date ON account_txns(account_id, txn_date)');

    await d.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        expense_date TEXT NOT NULL,
        amount REAL NOT NULL,
        account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
        pay_mode TEXT NOT NULL DEFAULT 'Cash',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await d.execute('''
      CREATE TABLE party_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_id INTEGER NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        pay_mode TEXT NOT NULL DEFAULT 'Cash',
        account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
        note TEXT NOT NULL DEFAULT '',
        pay_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await d.execute('''
      CREATE TABLE serials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serial TEXT NOT NULL UNIQUE,
        product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        product_name TEXT NOT NULL DEFAULT '',
        purchase_invoice_id INTEGER REFERENCES invoices(id) ON DELETE SET NULL,
        purchase_number TEXT NOT NULL DEFAULT '',
        sale_invoice_id INTEGER REFERENCES invoices(id) ON DELETE SET NULL,
        sale_number TEXT NOT NULL DEFAULT '',
        customer_id INTEGER REFERENCES parties(id) ON DELETE SET NULL,
        customer_name TEXT NOT NULL DEFAULT '',
        customer_phone TEXT NOT NULL DEFAULT '',
        sold_date TEXT,
        warranty_months INTEGER NOT NULL DEFAULT 0,
        warranty_start TEXT,
        warranty_expiry TEXT,
        status TEXT NOT NULL DEFAULT 'in_stock',
        created_at TEXT NOT NULL
      )
    ''');
    await d.execute('CREATE INDEX idx_serials_status ON serials(status)');

    await d.execute('''
      CREATE TABLE warranty_claims (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        serial_id INTEGER NOT NULL REFERENCES serials(id) ON DELETE CASCADE,
        claim_date TEXT NOT NULL,
        issue TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        resolution TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // Every shop starts with one cash account.
    await d.insert('accounts', {
      'kind': 'cash',
      'name': 'Cash',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
