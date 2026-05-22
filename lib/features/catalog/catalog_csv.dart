import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

/// ENH-010 — pure helpers for the Catalog bulk CSV flows. Kept separate
/// from the screen so the parsing is testable without Flutter bindings.

const List<String> kCsvHeader = [
  'id',
  'name',
  'category',
  'base_price',
  'sku',
  'is_active',
];

class CsvParseResult {
  CsvParseResult({required this.ok, required this.errors});
  final List<ProductsCompanion> ok;
  final List<String> errors;
}

/// Renders [rows] as an RFC 4180-ish CSV string. Always emits the canonical
/// header so round-trips are stable. Empty/null cells render as blanks.
String exportProductsToCsv(List<ProductRow> rows) {
  final buf = StringBuffer()..writeln(kCsvHeader.join(','));
  for (final r in rows) {
    buf.writeln([
      _esc(r.id),
      _esc(r.name),
      _esc(r.category ?? ''),
      r.basePrice.toStringAsFixed(0),
      _esc(r.sku ?? ''),
      r.isActive ? '1' : '0',
    ].join(','));
  }
  return buf.toString();
}

/// Parses CSV produced by [exportProductsToCsv] (or hand-edited variant).
/// Empty `id` cells get a fresh UUID v7. Unknown extra columns are
/// ignored. Required: `name`, `base_price`.
CsvParseResult parseProductsCsv(String raw, {Uuid? uuid}) {
  final ids = uuid ?? const Uuid();
  final out = <ProductsCompanion>[];
  final errors = <String>[];

  final lines = _splitRows(raw);
  if (lines.isEmpty) {
    return CsvParseResult(ok: out, errors: ['CSV kosong']);
  }
  final headerCells = _splitCells(lines.first);
  final headerIndex = {
    for (var i = 0; i < headerCells.length; i++)
      headerCells[i].trim().toLowerCase(): i,
  };
  for (final required in ['name', 'base_price']) {
    if (!headerIndex.containsKey(required)) {
      errors.add('Header wajib hilang: "$required"');
    }
  }
  if (errors.isNotEmpty) return CsvParseResult(ok: out, errors: errors);

  String? cell(List<String> cells, String key) {
    final i = headerIndex[key];
    if (i == null || i >= cells.length) return null;
    final v = cells[i].trim();
    return v.isEmpty ? null : v;
  }

  for (var i = 1; i < lines.length; i++) {
    final lineNo = i + 1; // 1-based, header counts
    final row = lines[i];
    if (row.trim().isEmpty) continue;
    final cells = _splitCells(row);
    final name = cell(cells, 'name');
    if (name == null) {
      errors.add('Baris $lineNo: kolom "name" kosong');
      continue;
    }
    final priceStr = cell(cells, 'base_price');
    final price = priceStr == null ? null : double.tryParse(priceStr);
    if (price == null) {
      errors.add('Baris $lineNo: "base_price" bukan angka ($priceStr)');
      continue;
    }
    final id = cell(cells, 'id') ?? ids.v7();
    final category = cell(cells, 'category');
    final sku = cell(cells, 'sku');
    final isActiveStr = cell(cells, 'is_active');
    final isActive = isActiveStr == null
        ? true
        : (isActiveStr == '1' ||
            isActiveStr.toLowerCase() == 'true' ||
            isActiveStr.toLowerCase() == 'yes');

    final now = DateTime.now();
    out.add(ProductsCompanion.insert(
      id: id,
      name: name,
      category: Value(category),
      basePrice: price,
      sku: Value(sku),
      isActive: Value(isActive),
      createdAt: now,
      updatedAt: now,
    ));
  }

  return CsvParseResult(ok: out, errors: errors);
}

// ── Internals ─────────────────────────────────────────────────────────────────

/// Escapes a field per RFC 4180: wrap in quotes if it contains a comma,
/// quote, or newline; double-up internal quotes.
String _esc(String v) {
  final needs =
      v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
  if (!needs) return v;
  return '"${v.replaceAll('"', '""')}"';
}

/// Splits the source into logical rows, respecting quoted newlines.
List<String> _splitRows(String src) {
  final rows = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < src.length; i++) {
    final ch = src[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
      buf.write(ch);
      continue;
    }
    if (!inQuotes && (ch == '\n' || ch == '\r')) {
      // Skip CRLF pair.
      if (ch == '\r' && i + 1 < src.length && src[i + 1] == '\n') i++;
      rows.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  if (buf.isNotEmpty) rows.add(buf.toString());
  return rows;
}

/// Splits a CSV row into cells, respecting quoting and `""` escapes.
List<String> _splitCells(String row) {
  final cells = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < row.length; i++) {
    final ch = row[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes && ch == ',') {
      cells.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  cells.add(buf.toString());
  return cells;
}
