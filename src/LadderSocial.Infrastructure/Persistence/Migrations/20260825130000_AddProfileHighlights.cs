using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LadderSocial.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddProfileHighlights : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "HighlightedAtUtc",
                table: "Posts",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsHighlighted",
                table: "Posts",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Posts_AuthorUserId_IsHighlighted_HighlightedAtUtc",
                table: "Posts",
                columns: new[] { "AuthorUserId", "IsHighlighted", "HighlightedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Posts_AuthorUserId_IsHighlighted_HighlightedAtUtc",
                table: "Posts");

            migrationBuilder.DropColumn(
                name: "HighlightedAtUtc",
                table: "Posts");

            migrationBuilder.DropColumn(
                name: "IsHighlighted",
                table: "Posts");
        }
    }
}
