import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:printing/printing.dart';

abstract interface class ReportPrintService {
  Future<bool> printPdf(DownloadedFile report);
}

final class NativeReportPrintService implements ReportPrintService {
  const NativeReportPrintService();

  @override
  Future<bool> printPdf(DownloadedFile report) => Printing.layoutPdf(
        name: report.fileName,
        onLayout: (_) async => report.bytes,
      );
}
