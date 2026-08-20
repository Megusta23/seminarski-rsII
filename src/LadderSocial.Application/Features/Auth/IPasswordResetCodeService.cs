namespace LadderSocial.Application.Features.Auth;

public sealed record GeneratedPasswordResetCode(
    string PlainTextCode,
    string CodeHash);

public interface IPasswordResetCodeService
{
    GeneratedPasswordResetCode CreateCode();
    string HashCode(string code);
    bool VerifyCode(string code, string expectedHash);
    string ProtectForTransport(string code);
    string UnprotectFromTransport(string protectedCode);
}
