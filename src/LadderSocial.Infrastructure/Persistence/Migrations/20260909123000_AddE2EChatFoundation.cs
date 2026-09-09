using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LadderSocial.Infrastructure.Persistence.Migrations
{
    public partial class AddE2EChatFoundation : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "ContentNonce",
                table: "Messages",
                type: "varbinary(24)",
                maxLength: 24,
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "EncryptedContent",
                table: "Messages",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "EncryptionVersion",
                table: "Messages",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "KeyVersion",
                table: "Messages",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "ContentNonce",
                table: "MessageAttachments",
                type: "varbinary(24)",
                maxLength: 24,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "DurationMilliseconds",
                table: "MessageAttachments",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "EncryptionVersion",
                table: "MessageAttachments",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "KeyVersion",
                table: "MessageAttachments",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "UserDeviceKeys",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    DeviceId = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    PublicKey = table.Column<byte[]>(type: "varbinary(32)", maxLength: 32, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastSeenAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RevokedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserDeviceKeys", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserDeviceKeys_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ConversationKeyEnvelopes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ConversationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RecipientDeviceKeyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderDeviceKeyId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    EncryptedConversationKey = table.Column<byte[]>(type: "varbinary(64)", maxLength: 64, nullable: false),
                    Nonce = table.Column<byte[]>(type: "varbinary(24)", maxLength: 24, nullable: false),
                    KeyVersion = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConversationKeyEnvelopes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConversationKeyEnvelopes_Conversations_ConversationId",
                        column: x => x.ConversationId,
                        principalTable: "Conversations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ConversationKeyEnvelopes_UserDeviceKeys_RecipientDeviceKeyId",
                        column: x => x.RecipientDeviceKeyId,
                        principalTable: "UserDeviceKeys",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ConversationKeyEnvelopes_UserDeviceKeys_SenderDeviceKeyId",
                        column: x => x.SenderDeviceKeyId,
                        principalTable: "UserDeviceKeys",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_ConversationKeyEnvelopes_ConversationId_RecipientDeviceKeyId_KeyVersion",
                table: "ConversationKeyEnvelopes",
                columns: new[] { "ConversationId", "RecipientDeviceKeyId", "KeyVersion" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ConversationKeyEnvelopes_RecipientDeviceKeyId",
                table: "ConversationKeyEnvelopes",
                column: "RecipientDeviceKeyId");

            migrationBuilder.CreateIndex(
                name: "IX_ConversationKeyEnvelopes_SenderDeviceKeyId",
                table: "ConversationKeyEnvelopes",
                column: "SenderDeviceKeyId");

            migrationBuilder.CreateIndex(
                name: "IX_UserDeviceKeys_UserId_DeviceId",
                table: "UserDeviceKeys",
                columns: new[] { "UserId", "DeviceId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserDeviceKeys_UserId_RevokedAtUtc",
                table: "UserDeviceKeys",
                columns: new[] { "UserId", "RevokedAtUtc" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ConversationKeyEnvelopes");

            migrationBuilder.DropTable(
                name: "UserDeviceKeys");

            migrationBuilder.DropColumn(
                name: "ContentNonce",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "EncryptedContent",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "EncryptionVersion",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "KeyVersion",
                table: "Messages");

            migrationBuilder.DropColumn(
                name: "ContentNonce",
                table: "MessageAttachments");

            migrationBuilder.DropColumn(
                name: "DurationMilliseconds",
                table: "MessageAttachments");

            migrationBuilder.DropColumn(
                name: "EncryptionVersion",
                table: "MessageAttachments");

            migrationBuilder.DropColumn(
                name: "KeyVersion",
                table: "MessageAttachments");
        }
    }
}
