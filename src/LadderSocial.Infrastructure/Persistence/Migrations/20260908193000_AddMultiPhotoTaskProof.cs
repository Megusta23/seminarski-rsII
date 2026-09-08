using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LadderSocial.Infrastructure.Persistence.Migrations
{
    public partial class AddMultiPhotoTaskProof : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ProofLayoutCode",
                table: "TaskCompletions",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.DropIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia");

            migrationBuilder.CreateIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia",
                column: "TaskCompletionId");

            migrationBuilder.CreateTable(
                name: "TaskProofItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TaskCompletionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OwnerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StorageKey = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    MimeType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    OrderIndex = table.Column<int>(type: "int", nullable: false),
                    LayoutSlot = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TaskProofItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TaskProofItems_AspNetUsers_OwnerUserId",
                        column: x => x.OwnerUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TaskProofItems_TaskCompletions_TaskCompletionId",
                        column: x => x.TaskCompletionId,
                        principalTable: "TaskCompletions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TaskProofItems_OwnerUserId",
                table: "TaskProofItems",
                column: "OwnerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TaskProofItems_TaskCompletionId_LayoutSlot",
                table: "TaskProofItems",
                columns: new[] { "TaskCompletionId", "LayoutSlot" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TaskProofItems_TaskCompletionId_OrderIndex",
                table: "TaskProofItems",
                columns: new[] { "TaskCompletionId", "OrderIndex" },
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "TaskProofItems");

            migrationBuilder.DropIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia");

            migrationBuilder.CreateIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia",
                column: "TaskCompletionId",
                unique: true);

            migrationBuilder.DropColumn(
                name: "ProofLayoutCode",
                table: "TaskCompletions");
        }
    }
}
