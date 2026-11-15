import 'package:flutter/material.dart';

/// Ein Eintrag im [ReportExportMenu].
class ReportExportMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  const ReportExportMenuItem({
    required this.icon,
    required this.label,
    required this.onSelected,
  });
}

/// Ein Button „PDF-Export“ mit Menü der verfügbaren PDF-Auswertungen
/// (Jahres-Tab, #284). Passt bei jeder Handy-Breite in eine Zeile und bleibt
/// es auch, wenn weitere Auswertungen dazukommen; die Beschriftung entspricht
/// dem Export-Button der übrigen Berichts-Tabs (`ReportActionRow`).
///
/// Das Menü öffnet unter dem Button und schließt bündig mit dessen rechter
/// Kante ab (Popup-Menü, hält Abstand zum Bildschirmrand).
class ReportExportMenu extends StatelessWidget {
  /// Sichtbare Beschriftung des Buttons.
  final String label;

  /// Tooltip (langer Druck) und Screenreader-Hinweis.
  final String tooltip;
  final List<ReportExportMenuItem> items;

  const ReportExportMenu({
    super.key,
    required this.label,
    required this.tooltip,
    required this.items,
  });

  Future<void> _open(BuildContext context) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<int>(
      context: context,
      position: position,
      items: [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(items[i].icon),
                const SizedBox(width: 12),
                Flexible(child: Text(items[i].label)),
              ],
            ),
          ),
      ],
    );
    if (selected != null && context.mounted) items[selected].onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
