using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LadderSocial.Infrastructure.Persistence.Migrations;

public partial class AddPasswordResetRequests : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "PasswordResetRequests",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CodeHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                ExpiresAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                AttemptCount = table.Column<int>(type: "int", nullable: false),
                UsedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                InvalidatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                EmailQueuedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                EmailSentAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                EmailDeliveryAttemptCount = table.Column<int>(type: "int", nullable: false),
                LastDeliveryError = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PasswordResetRequests", x => x.Id);
                table.ForeignKey(
                    name: "FK_PasswordResetRequests_AspNetUsers_UserId",
                    column: x => x.UserId,
                    principalTable: "AspNetUsers",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_PasswordResetRequests_ExpiresAtUtc",
            table: "PasswordResetRequests",
            column: "ExpiresAtUtc");

        migrationBuilder.CreateIndex(
            name: "IX_PasswordResetRequests_UserId_CreatedAtUtc",
            table: "PasswordResetRequests",
            columns: new[] { "UserId", "CreatedAtUtc" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "PasswordResetRequests");
    }
}
