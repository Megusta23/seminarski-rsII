using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LadderSocial.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddApplicationMilestones : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia");

            migrationBuilder.DropIndex(
                name: "IX_TaskCompletions_TaskItemId",
                table: "TaskCompletions");

            migrationBuilder.DropIndex(
                name: "IX_MessageAttachments_MessageId",
                table: "MessageAttachments");

            migrationBuilder.AddColumn<DateOnly>(
                name: "OccurrenceDate",
                table: "TaskCompletions",
                type: "date",
                nullable: false,
                defaultValue: new DateOnly(1, 1, 1));

            migrationBuilder.CreateIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia",
                column: "TaskCompletionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TaskCompletions_TaskItemId_UserId_OccurrenceDate",
                table: "TaskCompletions",
                columns: new[] { "TaskItemId", "UserId", "OccurrenceDate" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MessageAttachments_MessageId",
                table: "MessageAttachments",
                column: "MessageId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia");

            migrationBuilder.DropIndex(
                name: "IX_TaskCompletions_TaskItemId_UserId_OccurrenceDate",
                table: "TaskCompletions");

            migrationBuilder.DropIndex(
                name: "IX_MessageAttachments_MessageId",
                table: "MessageAttachments");

            migrationBuilder.DropColumn(
                name: "OccurrenceDate",
                table: "TaskCompletions");

            migrationBuilder.CreateIndex(
                name: "IX_TaskProofMedia_TaskCompletionId",
                table: "TaskProofMedia",
                column: "TaskCompletionId");

            migrationBuilder.CreateIndex(
                name: "IX_TaskCompletions_TaskItemId",
                table: "TaskCompletions",
                column: "TaskItemId");

            migrationBuilder.CreateIndex(
                name: "IX_MessageAttachments_MessageId",
                table: "MessageAttachments",
                column: "MessageId");
        }
    }
}
