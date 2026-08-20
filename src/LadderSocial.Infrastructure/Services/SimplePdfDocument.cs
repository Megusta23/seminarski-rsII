using System.Globalization;
using System.Text;

namespace LadderSocial.Infrastructure.Services;

internal static class SimplePdfDocument
{
    private const int LinesPerPage = 48;

    public static byte[] Create(string title, IReadOnlyCollection<string> sourceLines)
    {
        var lines = sourceLines.Count == 0 ? ["No data is available for this report."] : sourceLines.ToArray();
        var pages = lines
            .Chunk(LinesPerPage)
            .Select(chunk => chunk.ToArray())
            .ToArray();
        var pageCount = pages.Length;
        var fontObjectId = 3 + pageCount * 2;
        var objects = new SortedDictionary<int, byte[]>();

        objects[1] = Ascii("<< /Type /Catalog /Pages 2 0 R >>");
        var pageIds = Enumerable.Range(0, pageCount).Select(index => 3 + index * 2).ToArray();
        objects[2] = Ascii($"<< /Type /Pages /Count {pageCount} /Kids [{string.Join(" ", pageIds.Select(id => $"{id} 0 R"))}] >>");

        for (var index = 0; index < pageCount; index++)
        {
            var pageObjectId = 3 + index * 2;
            var contentObjectId = pageObjectId + 1;
            objects[pageObjectId] = Ascii(
                $"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] " +
                $"/Resources << /Font << /F1 {fontObjectId} 0 R >> >> /Contents {contentObjectId} 0 R >>");
            var content = BuildPageContent(title, pages[index], index + 1, pageCount);
            var contentBytes = Ascii(content);
            objects[contentObjectId] = Combine(
                Ascii($"<< /Length {contentBytes.Length} >>\nstream\n"),
                contentBytes,
                Ascii("\nendstream"));
        }

        objects[fontObjectId] = Ascii("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

        using var stream = new MemoryStream();
        Write(stream, Ascii("%PDF-1.4\n%LadderSocial\n"));
        var offsets = new Dictionary<int, long>();
        foreach (var pair in objects)
        {
            offsets[pair.Key] = stream.Position;
            Write(stream, Ascii($"{pair.Key} 0 obj\n"));
            Write(stream, pair.Value);
            Write(stream, Ascii("\nendobj\n"));
        }

        var xrefPosition = stream.Position;
        var objectCount = objects.Keys.Max() + 1;
        Write(stream, Ascii($"xref\n0 {objectCount}\n"));
        Write(stream, Ascii("0000000000 65535 f \n"));
        for (var id = 1; id < objectCount; id++)
        {
            var offset = offsets.GetValueOrDefault(id);
            Write(stream, Ascii($"{offset.ToString("0000000000", CultureInfo.InvariantCulture)} 00000 n \n"));
        }

        Write(stream, Ascii(
            $"trailer\n<< /Size {objectCount} /Root 1 0 R >>\n" +
            $"startxref\n{xrefPosition}\n%%EOF"));
        return stream.ToArray();
    }

    private static string BuildPageContent(
        string title,
        IReadOnlyCollection<string> lines,
        int pageNumber,
        int pageCount)
    {
        var builder = new StringBuilder();
        builder.AppendLine("BT");
        builder.AppendLine("/F1 16 Tf");
        builder.AppendLine("50 795 Td");
        builder.AppendLine($"({Escape(title)}) Tj");
        builder.AppendLine("0 -22 Td");
        builder.AppendLine("/F1 9 Tf");
        builder.AppendLine($"(Page {pageNumber} of {pageCount}) Tj");
        builder.AppendLine("0 -22 Td");
        builder.AppendLine("/F1 10 Tf");
        foreach (var line in lines)
        {
            builder.AppendLine($"({Escape(line)}) Tj");
            builder.AppendLine("0 -14 Td");
        }

        builder.AppendLine("ET");
        return builder.ToString();
    }

    private static string Escape(string value)
    {
        var sanitized = value
            .Replace('č', 'c')
            .Replace('ć', 'c')
            .Replace('ž', 'z')
            .Replace('š', 's')
            .Replace('đ', 'd')
            .Replace('Č', 'C')
            .Replace('Ć', 'C')
            .Replace('Ž', 'Z')
            .Replace('Š', 'S')
            .Replace('Đ', 'D');
        var ascii = new string(sanitized.Select(character => character is >= ' ' and <= '~' ? character : '?').ToArray());
        return ascii.Replace("\\", "\\\\").Replace("(", "\\(").Replace(")", "\\)");
    }

    private static byte[] Ascii(string value) => Encoding.ASCII.GetBytes(value);

    private static byte[] Combine(params byte[][] segments)
    {
        var result = new byte[segments.Sum(segment => segment.Length)];
        var offset = 0;
        foreach (var segment in segments)
        {
            Buffer.BlockCopy(segment, 0, result, offset, segment.Length);
            offset += segment.Length;
        }

        return result;
    }

    private static void Write(Stream stream, byte[] bytes) => stream.Write(bytes, 0, bytes.Length);
}
